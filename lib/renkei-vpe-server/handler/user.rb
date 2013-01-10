#
# Copyright 2011-2013 Shinichiro Takizawa
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


require 'renkei-vpe-server/handler/base'
require 'rexml/document'

module RenkeiVPE
  module Handler

    class UserHandler < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.user') do
        meth('val pool(string)',
             'Retrieve information about user group',
             'pool')
        meth('val ask_id(string, string)',
             'Retrieve id of the given-named user',
             'ask_id')
        meth('val info(string, int)',
             'Retrieve information about the user',
             'info')
        meth('val allocate(string, string, string)',
             'Allocates a new user',
             'allocate')
        meth('val delete(string, int)',
             'Deletes a user from the user pool',
             'delete')
        meth('val enable(string, int, bool)',
             'Enables or disables a user',
             'enable')
        meth('val passwd(string, int, string)',
             'Changes password for the given user',
             'passwd')
        meth('val enable_zone(string, int, bool, int, int)',
             'Enables or disables a user to use a zone',
             'enable_zone')
      end

      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # return information about user group.
      # +session+   string that represents user session
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the information string
      def pool(session)
        read_task('rvpe.user.pool', session, true) do
          pool_e = REXML::Element.new('USER_POOL')
          User.each(session) do |user|
            pool_e.add(user.to_xml_element(session))
          end
          doc = REXML::Document.new
          doc.add(pool_e)
          [true, doc.to_s]
        end
      end

      # return id of the given-named user.
      # +session+   string that represents user session
      # +name+      name of a user
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the id of the user
      def ask_id(session, name)
        read_task('rvpe.user.ask_id', session) do
          u = User.find_by_name(name).last
          raise "User[#{name}] is not found." unless u

          [true, u.id]
        end
      end

      # return information about this user.
      # +session+   string that represents user session
      # +id+        id of the user
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the string with the information
      #             about the user
      def info(session, id)
        read_task('rvpe.user.info', session) do
          session_uname = get_user_from_session(session)
          session_user = User.find_by_name(session_uname).last

          user = User.find_by_id(id).last
          raise "User[#{id}] is not found." unless user

          if session_user.id != 0 && session_user.id != id
            raise "You don't have permission to see info. of User[#{user.name}]."
          end

          doc = REXML::Document.new
          doc.add(user.to_xml_element(session))
          [true, doc.to_s]
        end
      end

      # allocates a new user.
      # +session+   string that represents user session
      # +name+      name of new user
      # +passwd+    password of new user
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is the error message,
      #             if successful this is the associated id (int uid)
      #             generated for this user
      def allocate(session, name, passwd)
        write_task('rvpe.user.allocate', session, true) do
          user = User.find_by_name(name)[0]
          raise "User[#{name}] already exists." if user

          rc = call_one_xmlrpc('one.user.allocate', session, name, passwd)
          raise rc[1] unless rc[0]

          begin
            user = User.new
            user.oid = rc[1]
            user.name = name
            user.create
          rescue => e
            call_one_xmlrpc('one.user.delete', session, rc[1])
            raise e
          end

          [true, user.id]
        end
      end

      # deletes a user.
      # +session+   string that represents user session
      # +id+        id for the user we want to delete
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def delete(session, id)
        task_name = 'rvpe.user.delete'
        write_task(task_name, session, true) do
          user = User.find_by_id(id)[0]
          raise "User[#{id}] does not exist." unless user

          # check if there are any running VMs or Images the user owns.
          # if any exist, this command will fail.
          # check the VM
          VirtualMachine.each("user_id=#{id}") do |vm|
            vm_e = vm.to_xml_element(session)
            stat = vm_e.get_elements('STATE')[0].text.to_i
            if stat != 6 && stat != 7
              raise "Can't delete a user who has incomplete VMs (whose state is neigher 'done' or 'fail'): User[#{user.name}]"
            end
          end
          # check the OS Image
          imgcnt = 0
          Image.each(session, user.oid) do |img|
            imgcnt += 1
          end
          if imgcnt != 0
            raise "Can't delete a user who has OS Images: User[#{user.name}]"
          end

          err_msg = ''

          rc = call_one_xmlrpc('one.user.delete', session, user.oid)
          unless rc[0]
            log_fail(task_name, rc[1])
            err_msg = (err_msg.size == 0)? rc[1] : err_msg +'; '+ rc[1]
          end
          begin
            release_all_leases(task_name, user)
          rescue => e
            err_msg = (err_msg.size == 0)? e.message : err_msg +'; '+ e.message
          end
          begin
            user.delete
          rescue => e
            log_fail(task_name, e)
            err_msg = (err_msg.size == 0)? e.message : err_msg +'; '+ e.message
          end

          raise err_msg unless err_msg.size == 0
          [true, '']
        end
      end

      # enables or disables a user
      # +session+   string that represents user session
      # +id+        id of the target user
      # +enabled+   true for enabling, false for disabling
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it is the user id.
      def enable(session, id, enabled)
        task_name = 'rvpe.user.enable'
        write_task(task_name, session, true) do
          user = User.find_by_id(id)[0]
          raise "User[#{id}] does not exist." unless user

          if enabled
            user.enabled = 1
          else
            user.enabled = 0
          end
          user.update

          unless enabled
            release_all_leases(task_name, user)
          end

          [true, user.id]
        end
      end

      # changes the password for the given user.
      # +session+   string that represents user session
      # +id+        id for the user to update the password
      # +passwd+    password of new user
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def passwd(session, id, passwd)
        write_task('rvpe.user.passwd', session, true) do
          user = User.find_by_id(id)[0]
          raise "User[#{id}] does not exist." unless user

          call_one_xmlrpc('one.user.passwd', session, user.oid, passwd)
        end
      end

      # enables/disables a user to use a zone
      # +session+   string that represents user session
      # +id+        id for the user
      # +enabled+   enable to use zone if true, otherwise disable to use
      # +zone_id+   id of zone
      # +limit+     maximum number of VMs the user can run in the zone
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it is maximum number of VMs when enabled is
      #             true and it does not exist when enabled is false.
      def enable_zone(session, id, enabled, zone_id, limit)
        write_task('rvpe.user.enable_zone', session, true) do
          user = User.find_by_id(id)[0]
          raise "User[#{id}] does not exist." unless user

          unless limit.kind_of? Integer
            if limit.instance_of?(String) && /^-?[0123456789]+$/ =~ limit
              limit = limit.to_i
            else
              raise 'limit attribute must be an integer: ' +
                "Can't specify '#{limit}'"
            end
          end
          limit = $server_config.user_limit if limit < 0

          user.modify_zone(zone_id, enabled, limit)
          user.update

          [true, enabled ? limit : '']
        end
      end


      private

      # It releases all leases assigned to the user
      # TODO it might be better if it can work with enable_zone
      def release_all_leases(task_name, user)
        targets = []
        Lease.each do |lease|
          if lease.assigned_to == user.id
            # can't run update here because Lease.each locks db.
            targets << lease
          end
        end

        err_msg = ''
        targets.each do |lease|
          begin
            lease.assigned_to = -1
            lease.update
          rescue => e
            log_fail(task_name, e)
            err_msg = (err_msg.size == 0)? e.message : err_msg+'; '+e.message
          end
        end

        raise err_msg unless err_msg.size == 0
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
