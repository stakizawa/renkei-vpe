#
# Copyright 2011-2013 Shinichiro Takizawa
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


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
      uid = self['ASSIGNED_TO_UID'].to_i
      if uid == -1
        '-'
      else
        self['ASSIGNED_TO_UNAME']
      end
    end
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
