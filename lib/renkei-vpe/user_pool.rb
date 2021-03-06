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
  class UserPool < Pool
    #######################################################################
    # Constants and Class attribute accessors
    #######################################################################

    USER_POOL_METHODS = {
      :info   => "user.pool",
      :ask_id => "user.ask_id"
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

    # Retrieves the id of the given-named user.
    # +name+  name of a user
    def ask_id(name)
      super(USER_POOL_METHODS[:ask_id], name)
    end
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
