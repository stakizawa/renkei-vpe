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
  class VirtualMachinePool < Pool
    #######################################################################
    # Constants and Class attribute accessors
    #######################################################################

    VM_POOL_METHODS = {
      :info   => "vm.pool",
      :ask_id => "vm.ask_id"
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

    # Retrieves the id of the given-named vm.
    # +name+  name of a vm
    def ask_id(name)
      super(VM_POOL_METHODS[:ask_id], name)
    end
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
