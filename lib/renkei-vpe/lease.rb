require 'renkei-vpe/pool'

module RenkeiVPE
    class Lease < PoolElement
        # ---------------------------------------------------------------------
        # Constants and Class Methods
        # ---------------------------------------------------------------------
        LEASE_METHODS = {
            :info      => "lease.info",
            :assign    => "lease.assign",
            :release   => "lease.release"
        }

        # Creates a lease description with just its identifier
        # this method should be used to create plain lease objects.
        # +id+ the id of the lease
        #
        # Example:
        #   type = Lease.new(Lease.build_xml(3),rpc_client)
        #
        def self.build_xml(pe_id=nil)
            if pe_id
                type_xml = "<LEASE><ID>#{pe_id}</ID></LEASE>"
            else
                type_xml = "<LEASE></LEASE>"
            end

            XMLElement.build_xml(type_xml,'LEASE')
        end

        # Class constructor
        def initialize(xml, client)
            super(xml,client)

            @client = client
        end

        #######################################################################
        # XML-RPC Methods for the Lease Object
        #######################################################################

        # Retrieves the information of the given Lease.
        def info()
            super(LEASE_METHODS[:info], 'LEASE')
        end

        # Assign this lease to a user
        def assign(user_name)
            return Error.new('ID not defined') if !@pe_id

            rc = @client.call(LEASE_METHODS[:assign], @pe_id, user_name)
            rc = nil if !RenkeiVPE.is_error?(rc)

            return rc
        end

        # Release this lease from a user
        def release
            return Error.new('ID not defined') if !@pe_id

            rc = @client.call(LEASE_METHODS[:release], @pe_id)
            rc = nil if !RenkeiVPE.is_error?(rc)

            return rc
        end

        #######################################################################
        # Helpers for getting data
        #######################################################################

        def vm_id_str
            vid = self['VID'].to_i
            if vid == -1
                '-'
            else
                vid
            end
        end

        def assigned_user
          uid = self['ASSIGNED_TO'].to_i
          if uid == -1
              '-'
          else
              'To be implemented'
          end
        end
    end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
