require 'renkei-vpe/pool'

module RenkeiVPE
  class User < PoolElement
    #######################################################################
    # Constants and Class Methods
    #######################################################################
    USER_METHODS = {
      :info          => "user.info",
      :allocate      => "user.allocate",
      :delete        => "user.delete",
      :passwd        => "user.passwd",
      :enable        => "user.enable",
      :enable_zone   => "user.enable_zone",
    }

    # Creates a User description with just its identifier
    # this method should be used to create plain User objects.
    # +id+ the id of the user
    #
    # Example:
    #   user = User.new(User.build_xml(3),rpc_client)
    #
    def User.build_xml(pe_id=nil)
      if pe_id
        user_xml = "<USER><ID>#{pe_id}</ID></USER>"
      else
        user_xml = "<USER></USER>"
      end

      XMLElement.build_xml(user_xml, 'USER')
    end

    #######################################################################
    # Class constructor
    #######################################################################
    def initialize(xml, client)
      super(xml,client)

      @client = client
    end

    #######################################################################
    # XML-RPC Methods for the User Object
    #######################################################################

    # Retrieves the information of the given User.
    def info()
      super(USER_METHODS[:info], 'USER')
    end

    # Allocates a new User in Renkei VPE
    #
    # +username+ Name of the new user.
    #
    # +password+ Password for the new user
    def allocate(username, password)
      rc = super(USER_METHODS[:allocate], username, password)
      if RenkeiVPE.is_error?(rc)
        return rc
      end

      @name = username
      return nil
    end

    # Enables the User
    def enable
      set_enabled(true)
    end

    # Disables the User
    def disable
      set_enabled(false)
    end

    # Deletes the User
    def delete
      super(USER_METHODS[:delete])
    end

    # Changes the password of the given User
    #
    # +password+ String containing the new password
    def passwd(password)
      return Error.new('ID not defined') if !@pe_id

      rc = @client.call(USER_METHODS[:passwd], @pe_id, password)
      rc = nil if !RenkeiVPE.is_error?(rc)

      return rc
    end

    # Enables the User to use the Zone
    def enable_zone(zone, limit)
      set_zone_enabled(true, zone, limit)
    end

    # Disables the User to use the Zone
    def disable_zone(zone)
      set_zone_enabled(false, zone)
    end

    private

    def set_enabled(enabled)
      return Error.new('ID not defined') if !@pe_id

      rc = @client.call(USER_METHODS[:enable], @pe_id, enabled)
      rc = nil if !RenkeiVPE.is_error?(rc)

      return rc
    end

    def set_zone_enabled(enabled, zone, limit=-1)
      return Error.new('ID not defined') if !@pe_id

      rc = @client.call(USER_METHODS[:enable_zone], @pe_id, enabled,
                        zone, limit)

      return rc
    end

  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
