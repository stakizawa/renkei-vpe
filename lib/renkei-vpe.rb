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


##############################################################################
# Environment Configuration
##############################################################################
one_location = ENV['ONE_LOCATION']

if !one_location
  ruby_lib_location = '/usr/lib/one/ruby'
else
  ruby_lib_location = one_location + '/lib/ruby'
end

$: << ruby_lib_location

##############################################################################
# Load libraries
##############################################################################
require 'xmlrpc/client'
require 'digest/sha1'

require 'renkei-vpe-common'
require 'renkei-vpe/xml_utils'
require 'renkei-vpe/pool'
require 'renkei-vpe/user'
require 'renkei-vpe/user_pool'
require 'renkei-vpe/image'
require 'renkei-vpe/image_pool'
require 'renkei-vpe/zone'
require 'renkei-vpe/zone_pool'
require 'renkei-vpe/host'
require 'renkei-vpe/host_pool'
require 'renkei-vpe/virtual_network'
require 'renkei-vpe/virtual_network_pool'
require 'renkei-vpe/lease'
require 'renkei-vpe/lease_pool'
require 'renkei-vpe/vm_type'
require 'renkei-vpe/vm_type_pool'
require 'renkei-vpe/virtual_machine'
require 'renkei-vpe/virtual_machine_pool'
require 'renkei-vpe/transfer'

##############################################################################
# RenkeiVPE module
##############################################################################
module RenkeiVPE
  class Error
    attr_reader :message

    # +message+ a description of the error
    def initialize(message=nil)
      @message = message
    end

    def to_str()
      @message
    end
  end

  def self.is_error?(value)
    value.class == RenkeiVPE::Error
  end

  def self.is_successful?(value)
    !self.is_error?(value)
  end

  class Client
    attr_accessor :one_auth

    begin
      require 'xmlparser'
      XMLPARSER=true
    rescue LoadError
      XMLPARSER=false
    end

    def initialize(secret=nil, endpoint=nil)
      if secret
        one_secret = secret
      elsif ENV["ONE_AUTH"] and !ENV["ONE_AUTH"].empty? and File.file?(ENV["ONE_AUTH"])
        one_secret=File.read(ENV["ONE_AUTH"])
      elsif File.file?(ENV["HOME"]+"/.rvpe_env/one_auth")
        one_secret=File.read(ENV["HOME"]+"/.rvpe_env/one_auth")
      else
        raise "Authentication file is not present"
      end

      if !one_secret.match(".+:.+")
        raise "Authorization file malformed"
      end

      one_secret=~/^(.+?):(.+)$/
      user=$1
      password=$2

      if password.match(/^plain:/)
        @one_auth = "#{user}:#{password.split(':').last}"
      else
        @one_auth = "#{user}:#{Digest::SHA1.hexdigest(password)}"
      end

      if endpoint
        @rvpe_endpoint=endpoint
      elsif ENV["RVPE_XMLRPC"]
        @rvpe_endpoint=ENV["RVPE_XMLRPC"]
      else
        @rvpe_endpoint="http://localhost:3111/"
      end

      @server=XMLRPC::Client.new2(@rvpe_endpoint)
    end

    def call(action, *args)
      if XMLPARSER
        @server.set_parser(XMLRPC::XMLParser::XMLStreamParser.new)
      end

      begin
        response = @server.call_async("rvpe."+action, @one_auth, *args)
        if response[0] == false
          Error.new(response[1])
        else
          response[1]
        end
      rescue Exception => e
        Error.new(e.message)
      end
    end
  end
end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
