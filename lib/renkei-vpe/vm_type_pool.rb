require 'renkei-vpe/pool'

module RenkeiVPE
    class VMTypePool < Pool
        #######################################################################
        # Constants and Class attribute accessors
        #######################################################################

        VMTYPE_POOL_METHODS = {
            :info => "vmtypepool.info"
        }

        #######################################################################
        # Class constructor & Pool Methods
        #######################################################################

        # +client+ a Client object that represents a XML-RPC connection
        def initialize(client)
            super('VMTYPE_POOL','VMTYPE',client)
        end

        # Factory Method for the VMType Pool
        def factory(element_xml)
            RenkeiVPE::VMType.new(element_xml,@client)
        end

        #######################################################################
        # XML-RPC Methods for the VMType Pool
        #######################################################################

        # Retrieves all the VM types in the pool.
        def info()
            super(VMTYPE_POOL_METHODS[:info])
        end
    end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
