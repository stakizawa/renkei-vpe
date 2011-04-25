require 'renkei-vpe/pool'

module RenkeiVPE
    class LeasePool < Pool
        #######################################################################
        # Constants and Class attribute accessors
        #######################################################################

        LEASE_POOL_METHODS = {
            :info => "lease.pool"
        }

        #######################################################################
        # Class constructor & Pool Methods
        #######################################################################

        # +client+ a Client object that represents a XML-RPC connection
        # +user_id+ is to refer to a Pool with Leases from that user
        def initialize(client, user_id=-1)
            super('LEASE_POOL','LEASE',client)
            @user_id = user_id
        end

        # Factory Method for the Lease Pool
        def factory(element_xml)
            RenkeiVPE::Lease.new(element_xml,@client)
        end

        #######################################################################
        # XML-RPC Methods for the Lease Pool
        #######################################################################

        # Retrieves all the VM types in the pool.
        def info()
            super(LEASE_POOL_METHODS[:info],@user_id)
        end
    end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
