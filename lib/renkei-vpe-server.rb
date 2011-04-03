##############################################################################
# Environment Configuration
##############################################################################
# obtain OnenNebula library path
one_location = ENV['ONE_LOCATION']

if !one_location
  ruby_lib_location = '/usr/lib/one/ruby'
else
  ruby_lib_location = one_location + '/lib/ruby'
end

$: << ruby_lib_location

# obtain Renkei-VPE path
$rvpe_path = File.dirname(File.dirname(File.expand_path(__FILE__)))

##############################################################################
# Load libraries
##############################################################################
require 'xmlrpc/server'
require 'yaml'
require 'pp'

require 'renkei-vpe-server/model'
require 'renkei-vpe-server/user'
require 'renkei-vpe-server/user_pool'
require 'renkei-vpe-server/image'
require 'renkei-vpe-server/image_pool'
require 'renkei-vpe-server/server_role'

##############################################################################
# RenkeiVPE module for the server
##############################################################################
module RenkeiVPE

  ############################################################################
  # Renkei VPE server components
  ############################################################################
  class Server
    def initialize(config)
      # initialize database
      RenkeiVPE::Database.init($rvpe_path + '/var/rvpe.db')

      # initialize one client
      RenkeiVPE::OpenNebulaClient.init(config.one_endpoint)

      # setup xml rpc methods
      rpcms = [
               [User::INTERFACE,      User.new],
               [UserPool::INTERFACE,  UserPool.new],
               [Image::INTERFACE,     Image.new],
               [ImagePool::INTERFACE, ImagePool.new],
              ]

      # setup xml rpc server
      @server = XMLRPC::Server.new(config.port)
      rpcms.each do |iface, obj|
        @server.add_handler(iface, obj)
      end
      # to support system.listMethods, system.methodSignature
      # and system.methodHelp
      @server.add_introspection
      # when method missing and wrong arguments
      @server.set_default_handler do |name, *args|
        raise XMLRPC::FaultException.new(-99, "Method #{name} missing" +
                                         " or wrong number of parameters!")
      end
    end

    def start
      @server.serve
    end

    # daemonize a block
    def self.daemonize(d_pid_file)
      return yield if $DEBUG

      pid = Process.fork do
        Process.setsid
        Dir.chdir '/'
        Signal.trap(:INT)  { exit! 0 }
        Signal.trap(:TERM) { exit! 0 }
        Signal.trap(:HUP)  { exit! 0 }
        File.open('/dev/null', 'r+') do |f|
          STDIN.reopen f
          STDOUT.reopen f
          STDERR.reopen f
        end
        yield
      end

      # write pid of daemon process
      File.open(d_pid_file, 'w') do |f|
        f.puts pid
      end
      exit! 0
    end
  end

  class ServerConfig
    DEFAULTS = {
      'port' => '8081',
      'one_endpoint' => 'http://localhost:2633/RPC2',
    }

    def self.read_config(conf_file)
      # load configs defined in 'conf_file' to the config
      ServerConfig.new(YAML.load_file(conf_file))
    end

    def initialize(conf_hash)
      @configs = DEFAULTS.merge(conf_hash)
    end

    def method_missing(action, *args)
      param = action.to_s

      unless args.size == 0
        raise Exception, "Argument error: #{param}"
      end

      val = @configs[param]
      unless val
        raise Exception, "Unknown config parameter: #{param}"
      end
      return val
    end
  end


  ############################################################################
  # Implement xml rpc interfaces
  ############################################################################
  class User
    INTERFACE = XMLRPC::interface('rvpe.user') do
      meth('val info(string, int)',
           'Retrieve information about the user',
           'info')
      meth('val allocate(string, string, string)',
           'Allocates a new user',
           'allocate')
      meth('val delete(string, int)',
           'Deletes a user from the user pool',
           'delete')
      meth('val enable(string, int, bool)',
           'Enables or disables a user',
           'enable')
      meth('val passwd(string, int, string)',
           'Changes password for the given user',
           'passwd')
    end
  end

  class UserPool
    INTERFACE = XMLRPC::interface('rvpe.userpool') do
      meth('val info(string)',
           'Retrieve information about user pool',
           'info')
    end
  end

  class Image
    INTERFACE = XMLRPC::interface('rvpe.image') do
      meth('val info(string, int)',
           'Retrieve information about the image',
           'info')
      meth('val allocate(string, string)',
           'Allocates a new image',
           'allocate')
      meth('val delete(string, int)',
           'Deletes an image from the image pool',
           'delete')
      meth('val enable(string, int, bool)',
           'Enables or disables an image',
           'enable')
      meth('val publish(string, int, bool)',
           'Publishes or unpublishes an image',
           'publish')
    end
  end

  class ImagePool
    INTERFACE = XMLRPC::interface('rvpe.imagepool') do
      meth('val info(string, int)',
           'Retrieve information about image pool',
           'info')
    end
  end

end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
