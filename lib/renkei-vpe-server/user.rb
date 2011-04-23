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
      meth('val enable_zone(string, int, bool, int)',
           'Enables or disables a user to use a zone',
           'enable_zone')
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
      task('rvpe.user.info', session, true) do
        user = RenkeiVPE::Model::User.find_by_id(id)[0]
        raise "User[#{id}] is not found" unless user
        rc = call_one_xmlrpc('one.user.info', session, user.oid)
        raise rc[1] unless rc[0]

        doc = REXML::Document.new(rc[1])
        doc.each_element('/USER') do |e|
          User.modify_onexml(e, id)
        end

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
        user = RenkeiVPE::Model::User.find_by_name(name)[0]
        raise "User[#{name}] already exists." if user

        rc = call_one_xmlrpc('one.user.allocate', session, name, passwd)
        raise rc[1] unless rc[0]

        begin
          user = RenkeiVPE::Model::User.new(-1, rc[1], name, 1, '')
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
        user = RenkeiVPE::Model::User.find_by_id(id)[0]
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
        user = RenkeiVPE::Model::User.find_by_id(id)[0]
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
        user = RenkeiVPE::Model::User.find_by_id(id)[0]
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
        user = RenkeiVPE::Model::User.find_by_id(id)[0]
        raise "User[#{id}] does not exist." unless user

        zids = user.zones.strip.split(/\s+/).map { |i| i.to_i }
        if enabled
          unless zids.include? zone_id
            zids << zone_id
          end
        else
          if zids.include? zone_id
            zids.delete(zone_id)
          end
        end
        user.zones = zids.join(' ')
        user.update

        [true, '']
      end
    end


    # It modifies xml obtained from one.
    # It does 1)replace user id, 2)replace enabled and 3)insert zones.
    # +id+ id of the user
    def self.modify_onexml(e, id=nil)
      if id
        user = RenkeiVPE::Model::User.find_by_id(id)[0]
      else
        name_e = e.get_elements('NAME')[0]
        name = name_e.get_text
        user = RenkeiVPE::Model::User.find_by_name(name)[0]
      end

      # 1. replace user id
      e.delete_element('ID')
      id_e = REXML::Element.new('ID')
      id_e.add(REXML::Text.new(user.id.to_s))
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
