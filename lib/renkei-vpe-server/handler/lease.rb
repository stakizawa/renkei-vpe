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
require 'renkei-vpe-server/resource_file'
require 'rexml/document'

module RenkeiVPE
  module Handler

    class LeaseHandler < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.lease') do
        meth('val pool(string, int)',
             'Retrieve information about lease group',
             'pool')
        meth('val ask_id(string, string)',
             'Retrieve id of the given-named lease',
             'ask_id')
        meth('val info(string, int)',
             'Retrieve information about the lease',
             'info')
        meth('val assign(string, int, string)',
             'assign a lease to a user',
             'assign')
        meth('val release(string, int)',
             'release a lease from the lease pool',
             'release')
      end

      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # return information about lease group.
      # +session+   string that represents user session
      # +flag+      flag for condition
      #             if flag <  -1, return all leases
      #             if flag == -1, return mine & available leases
      #             if flag >=  0, return user's leases
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the information string
      def pool(session, flag)
        read_task('rvpe.lease.pool', session) do
          uname = get_user_from_session(session)
          user = User.find_by_name(uname).last

          if flag < -1 || (flag >= 0 && flag != user.id)
            admin_session(session) do; end
          else # flag == -1
          end

          # lease search condition
          l_cond = nil
          if flag == -1
            l_cond = "assigned_to=#{user.id} OR (assigned_to=-1 AND used=0)"
          elsif flag >= 0
            l_cond = "assigned_to=#{flag}"
          end

          pool_e = REXML::Element.new('LEASE_POOL')
          Lease.each(l_cond) do |lease|
            lease_e = lease.to_xml_element(session)
            pool_e.add(lease_e)
          end
          doc = REXML::Document.new
          doc.add(pool_e)
          [true, doc.to_s]
        end
      end

      # return id of the given-named lease.
      # +session+   string that represents user session
      # +name+      name of a lease
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the id of the lease
      def ask_id(session, name)
        read_task('rvpe.lease.ask_id', session) do
          l = Lease.find_by_name(name).last
          raise "Lease[#{name}] is not found. " unless l

          [true, l.id]
        end
      end

      # return information about this lease.
      # +session+   string that represents user session
      # +id+        id of the user
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the string with the information
      #             about the user
      def info(session, id)
        read_task('rvpe.lease.info', session) do |lease|
          err_msg = "You don't have permission to query info. of the VM."
          sanity_check(session, id, err_msg) do |lease|
            lease_e = lease.to_xml_element(session)
            doc = REXML::Document.new
            doc.add(lease_e)

            [true, doc.to_s]
          end
        end
      end

      # assign a lease to a user
      # +session+   string that represents user session
      # +id+        id of a lease to be assigned
      # +user_name+ user name
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is the error message,
      #             otherwise it does not exist.
      def assign(session, id, user_name)
        write_task('rvpe.lease.allocate', session, true) do
          lease = Lease.find_by_id(id)[0]
          raise "Lease[#{id}] is not found." unless lease

          if lease.assigned_to >= 0
            # already assigned to another user
            user = User.find_by_id(lease.assigned_to)[0]
            user = lease.assigned_to unless user
            raise "Lease[#{id}] is already assigned to User[#{user.name}]."
          end

          user = User.find_by_name(user_name).last
          raise "User[#{user_name}] does not exist." unless user

          lease.assigned_to = user.id
          lease.update
          [true, '']
        end
      end

      # release a lease.
      # +session+   string that represents user session
      # +id+        id for the lease we want to release
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def release(session, id)
        write_task('rvpe.lease.delete', session, true) do
          lease = Lease.find_by_id(id)[0]
          raise "Lease[#{id}] does not exist." unless lease

          if lease.assigned_to < 0
            # the lease have not been assigned
            raise "Lease[#{id}] have not been assigned to any user."
          end

          lease.assigned_to = -1
          lease.update
          [true, '']
        end
      end

      private

      # It checks access permission
      def sanity_check(session, l_id, err_msg=nil)
        lease = Lease.find_by_id(l_id)[0]
        raise "Lease[#{l_id}] does not exist." unless lease
        unless lease_is_owned_by_session_owner?(lease, session)
          admin_session(session, true, err_msg) do; end
        end
        yield lease
      end

      # It returns true if the __lease__ is owned by the __session__ owner.
      def lease_is_owned_by_session_owner?(lease, session)
        uname = get_user_from_session(session)
        user = User.find_by_name(uname).last
        if lease.assigned_to == user.id
          true
        else
          false
        end
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
