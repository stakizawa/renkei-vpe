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
  class ZonePool < Pool
    #######################################################################
    # Constants and Class attribute accessors
    #######################################################################

    ZONE_POOL_METHODS = {
      :info   => "zone.pool",
      :ask_id => "zone.ask_id"
    }

    #######################################################################
    # Class constructor & Pool Methods
    #######################################################################

    # +client+ a Client object that represents a XML-RPC connection
    def initialize(client)
      super('ZONE_POOL','ZONE',client)
    end

    # Factory method to create Zone objects
    def factory(element_xml)
      RenkeiVPE::Zone.new(element_xml,@client)
    end

    #######################################################################
    # XML-RPC Methods for the Zone Object
    #######################################################################

    # Retrieves all the Zones in the pool.
    def info()
      super(ZONE_POOL_METHODS[:info])
    end

    # Retrieves the id of the given-named zone.
    # +name+  name of a zone
    def ask_id(name)
      super(ZONE_POOL_METHODS[:ask_id], name)
    end
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
