require 'renkei-vpe/pool'

module RenkeiVPE
    class VirtualMachinePool < Pool
        #######################################################################
        # Constants and Class attribute accessors
        #######################################################################

        VM_POOL_METHODS = {
            :info => "vm.pool"
        }

        #######################################################################
        # Class constructor & Pool Methods
        #######################################################################

        # +client+ a Client object that represents a XML-RPC connection
        def initialize(client, user_id=-1, history=-1)
            super('VM_POOL','VM',client)

            @user_id = user_id
            @history = history
        end

        # Factory Method for the VirtualMachine Pool
        def factory(element_xml)
            RenkeiVPE::VirtualMachine.new(element_xml,@client)
        end

        #######################################################################
        # XML-RPC Methods for the VirtualMachine Pool
        #######################################################################

        # Retrieves all the VMs in the pool.
        def info
            super(VM_POOL_METHODS[:info], @user_id, @history)
        end
    end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
