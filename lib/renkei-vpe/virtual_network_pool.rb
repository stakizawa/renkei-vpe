require 'renkei-vpe/pool'

module RenkeiVPE
    class VirtualNetworkPool < Pool
        #######################################################################
        # Constants and Class attribute accessors
        #######################################################################

        HOST_POOL_METHODS = {
            :info => "vnpool.info"
        }

        #######################################################################
        # Class constructor & Pool Methods
        #######################################################################

        # +client+ a Client object that represents a XML-RPC connection
        def initialize(client)
            super('VNET_POOL','VNET',client)
        end

        # Factory Method for the Host Pool
        def factory(element_xml)
            RenkeiVPE::Host.new(element_xml,@client)
        end

        #######################################################################
        # XML-RPC Methods for the Host Pool
        #######################################################################

        # Retrieves all the Hosts in the pool.
        def info()
            super(HOST_POOL_METHODS[:info])
        end
    end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
