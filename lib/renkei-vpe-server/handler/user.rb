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
        meth('val enable_zone(string, int, bool, int)',
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
        task('rvpe.user.pool', session, true) do
          pool_e = REXML::Element.new('USER_POOL')
          User.each(session) do |user|
            pool_e.add(user.to_xml_element(session))
          end
          doc = REXML::Document.new
          doc.add(pool_e)
          [true, doc.to_s]
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
        task('rvpe.user.info', session, true) do
          user = User.find_by_id(id)[0]
          raise "User[#{id}] is not found" unless user

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
        task('rvpe.user.allocate', session, true) do
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
        task('rvpe.user.delete', session, true) do
          user = User.find_by_id(id)[0]
          raise "User[#{id}] does not exist." unless user

          rc = call_one_xmlrpc('one.user.delete', session, user.oid)
          raise rc[1] unless rc[0]
          user.delete

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
        task('rvpe.user.enable', session, true) do
          user = User.find_by_id(id)[0]
          raise "User[#{id}] does not exist." unless user

          if enabled
            user.enabled = 1
          else
            user.enabled = 0
          end
          user.update

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
        task('rvpe.user.passwd', session, true) do
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
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def enable_zone(session, id, enabled, zone_id)
        task('rvpe.user.enable_zone', session, true) do
          user = User.find_by_id(id)[0]
          raise "User[#{id}] does not exist." unless user

          user.modify_zones(zone_id, enabled)
          user.update
          [true, '']
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
