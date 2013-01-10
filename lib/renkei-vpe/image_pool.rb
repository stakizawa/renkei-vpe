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
  class ImagePool < Pool
    #######################################################################
    # Constants and Class attribute accessors
    #######################################################################

    IMAGE_POOL_METHODS = {
      :info   => "image.pool",
      :ask_id => "image.ask_id"
    }

    #######################################################################
    # Class constructor & Pool Methods
    #######################################################################

    # +client+ a Client object that represents a XML-RPC connection
    # +user_id+ is to refer to a Pool with Images from that user
    def initialize(client, user_id=-1)
      super('IMAGE_POOL','IMAGE',client)

      @user_id  = user_id
    end

    # Default Factory Method for the Pools
    def factory(element_xml)
      RenkeiVPE::Image.new(element_xml,@client)
    end

    #######################################################################
    # XML-RPC Methods for the Image Object
    #######################################################################

    # Retrieves all or part of the Images in the pool.
    def info()
      super(IMAGE_POOL_METHODS[:info],@user_id)
    end

    # Retrieves the id of the given-named image.
    # +name+  name of an image
    # [return] nil in case of success or an Error object
    def ask_id(name)
      super(IMAGE_POOL_METHODS[:ask_id], name)
    end
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
