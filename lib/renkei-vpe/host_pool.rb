require 'renkei-vpe/pool'

module RenkeiVPE
    class HostPool < Pool
        #######################################################################
        # Constants and Class attribute accessors
        #######################################################################

        HOST_POOL_METHODS = {
            :info   => "host.pool",
            :ask_id => "host.ask_id",
        }

        #######################################################################
        # Class constructor & Pool Methods
        #######################################################################

        # +client+ a Client object that represents a XML-RPC connection
        def initialize(client)
            super('HOST_POOL','HOST',client)
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

        # Retrieves the id of the given-named host.
        # +name+  name of a host
        def ask_id(name)
            super(HOST_POOL_METHODS[:ask_id], name)
        end
    end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
