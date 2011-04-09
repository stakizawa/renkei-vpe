require 'renkei-vpe/pool'

module RenkeiVPE
  class Zone < PoolElement
    ##########################################################################
    # Constants and Class Methods
    ##########################################################################
    ZONE_METHODS = {
      :info     => 'zone.info',
      :allocate => 'zone.allocate',
      :delete   => 'zone.delete',
      :addhost  => 'zone.add_host',
      :rmhost   => 'zone.remove_host',
      :addvnet  => 'zone.add_vnet',
      :rmvnet   => 'zone.remove_vnet',
      :sync     => 'zone.sync'
    }

    # Creates a Zone description with just its identifier.
    # This method should be used to create plain Zone objects.
    # +id+ the id of the user
    #
    def Zone.build_xml(id=nil)
      if id
        user_xml = "<ZONE><ID>#{id}</ID></ZONE>"
      else
        user_xml = "<ZONE></ZONE>"
      end

      XMLElement.build_xml(user_xml, 'ZONE')
    end

    ##########################################################################
    # Class constructor
    ##########################################################################
    def initialize(xml, client)
      super(xml, client)
      @client = client
    end

    ##########################################################################
    # XML-RPC Methods for the Zone Object
    ##########################################################################

    # Retrieves the information of the given Zone.
    def info()
      super(ZONE_METHODS[:info], 'ZONE')
    end

    # Allocate a new Zone in RenkeiVPE
    #
    # +description+ A string containing the description of the Zone.
    def allocate(description)
      super(ZONE_METHODS[:allocate], description)
    end

    # Delete a Zone from RenkeiVPE
    def delete
      super(ZONE_METHODS[:delete])
    end

    # Add a new host to this Zone
    def addhost(host_name)
      call_rpc_for_target(ZONE_METHODS[:addhost], host_name)
    end

    # Remove a host from this Zone
    def rmhost(host_name)
      call_rpc_for_target(ZONE_METHODS[:rmhost], host_name)
    end

    # Add a new virtual network to this Zone
    def addvnet(vn_description)
      call_rpc_for_target(ZONE_METHODS[:addvnet], vn_description)
    end

    # Remove a virtual network from this Zone
    def rmvnet(vn_name)
      call_rpc_for_target(ZONE_METHODS[:rmvnet], vn_name)
    end

    # Synchronize probes with remote hosts
    def sync
      rc = @client.call(ZONE_METHODS[:sync])
      rc = nil if !RenkeiVPE.is_error?(rc)
      return rc
    end

    ##########################################################################
    # Helpers
    ##########################################################################

    # Register a new zone
    def register(description)
      rc = allocate(description)
      return rc if RenkeiVPE.is_error?(rc)

      rc = self.info
      rc = nil if !RenkeiVPE.is_error?(rc)

      return rc
    end


    private

    def call_rpc_for_target(method, target)
      return Error.new('ID not defined') if !@pe_id

      rc = @client.call(method, @pe_id, target)
      rc = nil if !RenkeiVPE.is_error?(rc)

      return rc
    end

  end
end

# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
