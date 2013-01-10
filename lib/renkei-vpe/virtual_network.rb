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
  class VirtualNetwork < PoolElement
    #######################################################################
    # Constants and Class Methods
    #######################################################################
    VN_METHODS = {
      :info     => 'vn.info',
      :adddns   => 'vn.add_dns',
      :rmdns    => 'vn.remove_dns',
      :addntp   => 'vn.add_ntp',
      :rmntp    => 'vn.remove_ntp',
      :addlease => 'vn.add_lease',
      :rmlease  => 'vn.remove_lease'
    }

    # Creates a VirtualNetwork description with just its identifier
    # this method should be used to create plain VirtualNetwork objects.
    # +id+ the id of the network
    #
    # Example:
    #   vnet = VirtualNetwork.new(VirtualNetwork.build_xml(3),rpc_client)
    #
    def VirtualNetwork.build_xml(pe_id=nil)
      if pe_id
        vn_xml = "<VNET><ID>#{pe_id}</ID></VNET>"
      else
        vn_xml = "<VNET></VNET>"
      end

      XMLElement.build_xml(vn_xml, 'VNET')
    end

    # Class constructor
    def initialize(xml, client)
      super(xml,client)

      @client = client
    end

    #######################################################################
    # XML-RPC Methods for the Virtual Network Object
    #######################################################################

    # Retrieves the information of the given VirtualNetwork.
    def info()
      super(VN_METHODS[:info], 'VNET')
    end

    # Adds dns servers
    def adddns(servers_str)
      call_rpc_for_target(VN_METHODS[:adddns], servers_str)
    end

    # Removes dns servers
    def rmdns(servers_str)
      call_rpc_for_target(VN_METHODS[:rmdns], servers_str)
    end

    # Adds ntp servers
    def addntp(servers_str)
      call_rpc_for_target(VN_METHODS[:addntp], servers_str)
    end

    # Removes ntp servers
    def rmntp(servers_str)
      call_rpc_for_target(VN_METHODS[:rmntp], servers_str)
    end

    # Adds a VM lease
    def addlease(name, ip_addr)
      call_rpc_for_target(VN_METHODS[:addlease], name, ip_addr)
    end

    # Removes a VM lease
    def rmlease(name)
      call_rpc_for_target(VN_METHODS[:rmlease], name)
    end

    ##########################################################################
    # Helpers
    ##########################################################################

    private

    def call_rpc_for_target(method, *target)
      return Error.new('ID not defined') if !@pe_id

      rc = @client.call(method, @pe_id, *target)
      rc = nil if !RenkeiVPE.is_error?(rc)

      return rc
    end

  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
