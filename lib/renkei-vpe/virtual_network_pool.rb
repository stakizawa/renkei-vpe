require 'renkei-vpe/pool'

module RenkeiVPE
  class VirtualNetworkPool < Pool
    #######################################################################
    # Constants and Class attribute accessors
    #######################################################################

    VN_POOL_METHODS = {
      :info   => "vn.pool",
      :ask_id => "vn.ask_id"
    }

    #######################################################################
    # Class constructor & Pool Methods
    #######################################################################

    # +client+ a Client object that represents a XML-RPC connection
    def initialize(client)
      super('VNET_POOL','VNET',client)
    end

    # Factory Method for the VirtualNetwork Pool
    def factory(element_xml)
      RenkeiVPE::VirtualNetwork.new(element_xml,@client)
    end

    #######################################################################
    # XML-RPC Methods for the VirtualNetwork Pool
    #######################################################################

    # Retrieves all the VNETs in the pool.
    def info()
      super(VN_POOL_METHODS[:info])
    end

    # Retrieves the id of the given-named Vnet.
    # +name+  name of a Vnet
    def ask_id(name)
      super(VN_POOL_METHODS[:ask_id], name)
    end
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
