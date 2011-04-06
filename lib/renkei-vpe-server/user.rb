require 'renkei-vpe-server/server_role'
require 'rexml/document'

module RenkeiVPE
  class User < ServerRole
    ##########################################################################
    # Define xml rpc interfaces
    ##########################################################################
    INTERFACE = XMLRPC::interface('rvpe.user') do
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
    end


    ##########################################################################
    # Implement xml rpc functions
    ##########################################################################

    # return information about this user.
    # +session+   string that represents user session
    # +id+        id of the user
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the string with the information
    #             about the user
    def info(session, id)
      authenticate(session, true) do
        method_name = 'rvpe.user.info'

        user = RenkeiVPE::Model::User.find_by_id(id)
        unless user
          msg = "User[#{id}] is not found"
          log_fail_exit(method_name, msg)
          return [false, msg]
        end
        rc = call_one_xmlrpc('one.user.info', session, user.oid)
        unless rc[0]
          log_fail_exit(method_name, rc[1])
          return rc
        end

        doc = REXML::Document.new(rc[1])
        doc.each_element('/USER') do |e|
          User.modify_onexml(e, id)
        end

        log_success_exit(method_name)
        return [true, doc.to_s]
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
      authenticate(session, true) do
        method_name = 'rvpe.user.allocate'

        user = RenkeiVPE::Model::User.find_by_name(name)
        if user
          msg = "User already exists: #{name}"
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        rc = call_one_xmlrpc('one.user.allocate', session, name, passwd)
        unless rc[0]
          log_fail_exit(method_name, rc[1])
          return rc
        end

        begin
          user = RenkeiVPE::Model::User.new
          user.name = name
          user.enabled = 1
          user.oid = rc[1]
          user.create
        rescue => e
          log_fail_exit(method_name, e)
          return [false, e.message]
        end

        log_success_exit(method_name)
        return [true, user.id]
      end
    end

    # deletes a user.
    # +session+   string that represents user session
    # +id+        id for the user we want to delete
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             otherwise it does not exist.
    def delete(session, id)
      authenticate(session, true) do
        method_name = 'rvpe.user.delete'

        user = RenkeiVPE::Model::User.find_by_id(id)
        unless user
          msg = "User[#{id}] does not exist."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        rc = call_one_xmlrpc('one.user.delete', session, user.oid)
        unless rc[0]
          log_fail_exit(method_name, rc[1])
          return rc
        end

        begin
          user.delete
        rescue => e
          log_fail_exit(method_name, e)
          return [false, e.message]
        end

        log_success_exit(method_name)
        return [true, '']
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
      authenticate(session, true) do
        method_name = 'rvpe.user.enable'

        user = RenkeiVPE::Model::User.find_by_id(id)
        unless user
          msg = "User[#{id}] does not exist."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        begin
          if enabled
            user.enabled = 1
          else
            user.enabled = 0
          end
          user.update
        rescue => e
          log_fail_exit(method_name, e)
          return [false, e.message]
        end

        log_success_exit(method_name)
        return [true, user.id]
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
      authenticate(session, true) do
        method_name = 'rvpe.user.passwd'

        user = RenkeiVPE::Model::User.find_by_id(id)
        unless user
          msg = "User[#{id}] does not exist."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        rc = call_one_xmlrpc('one.user.passwd', session, user.oid, passwd)
        log_result(method_name, rc)
        return rc
      end
    end

    def update_zones(session, id, zones)
      # TODO
      raise NotImplementedError
    end


    # It modifies xml obtained from one.
    # It does 1)replace user id, 2)replace enabled and 3)insert zones.
    # +id+ id of the user
    def self.modify_onexml(e, id=nil)
      if id
        user = RenkeiVPE::Model::User.find_by_id(id)
      else
        name_e = e.get_elements('NAME')[0]
        name = name_e.get_text
        user = RenkeiVPE::Model::User.find_by_name(name)
      end

      # 1. replace user id
      e.delete_element('ID')
      id_e = REXML::Element.new('ID')
      id_e.add(REXML::Text.new(user.id))
      e.add(id_e)

      # 2. replace enabled
      e.delete_element('ENABLED')
      enabled_e = REXML::Element.new('ENABLED')
      enabled_e.add(REXML::Text.new(user.enabled.to_s))
      e.add(enabled_e)

      # 3. insert zones
      zones_e = REXML::Element.new('ZONES')
      zones_e.add(REXML::Text.new(user.zones))
      e.add(zones_e)
    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
