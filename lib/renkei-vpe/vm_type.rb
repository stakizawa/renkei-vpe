#
# Copyright 2011-2012 Shinichiro Takizawa
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
  class VMType < PoolElement
    # ---------------------------------------------------------------------
    # Constants and Class Methods
    # ---------------------------------------------------------------------
    VMTYPE_METHODS = {
      :info        => "vmtype.info",
      :allocate    => "vmtype.allocate",
      :delete      => "vmtype.delete"
    }

    # Creates a VM type description with just its identifier
    # this method should be used to create plain VMType objects.
    # +id+ the id of the VM type
    #
    # Example:
    #   type = VMType.new(VMType.build_xml(3),rpc_client)
    #
    def self.build_xml(pe_id=nil)
      if pe_id
        type_xml = "<VMTYPE><ID>#{pe_id}</ID></VMTYPE>"
      else
        type_xml = "<VMTYPE></VMTYPE>"
      end

      XMLElement.build_xml(type_xml,'VMTYPE')
    end

    # Class constructor
    def initialize(xml, client)
      super(xml,client)

      @client = client
    end

    #######################################################################
    # XML-RPC Methods for the VMType Object
    #######################################################################

    # Retrieves the information of the given VMType.
    def info()
      super(VMTYPE_METHODS[:info], 'VMTYPE')
    end

    # Allocates a new VMType in RenkeiVPE
    #
    # +description+ A string containing the template of the VM type.
    def allocate(description)
      result = super(VMTYPE_METHODS[:allocate],description)
      self.info
      return result
    end

    # Deletes the VM Type
    def delete()
      super(VMTYPE_METHODS[:delete])
    end

  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
