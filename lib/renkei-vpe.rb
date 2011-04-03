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

require 'renkei-vpe/xml_utils'
require 'renkei-vpe/pool'
require 'renkei-vpe/user'
require 'renkei-vpe/user_pool'
require 'renkei-vpe/image'
require 'renkei-vpe/image_pool'

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
      elsif File.file?(ENV["HOME"]+"/.one/one_auth")
        one_secret=File.read(ENV["HOME"]+"/.one/one_auth")
      else
        raise "ONE_AUTH file not present"
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
        @rvpe_endpoint="http://localhost:8080/"
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