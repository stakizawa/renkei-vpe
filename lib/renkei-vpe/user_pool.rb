require 'renkei-vpe/pool'

module RenkeiVPE
    class UserPool < Pool
        #######################################################################
        # Constants and Class attribute accessors
        #######################################################################

        USER_POOL_METHODS = {
            :info => "userpool.info"
        }

        #######################################################################
        # Class constructor & Pool Methods
        #######################################################################

        # +client+ a Client object that represents a XML-RPC connection
        def initialize(client)
            super('USER_POOL','USER',client)
        end

        # Factory method to create User objects
        def factory(element_xml)
            RenkeiVPE::User.new(element_xml,@client)
        end

        #######################################################################
        # XML-RPC Methods for the User Object
        #######################################################################

        # Retrieves all the Users in the pool.
        def info()
            super(USER_POOL_METHODS[:info])
        end
    end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
