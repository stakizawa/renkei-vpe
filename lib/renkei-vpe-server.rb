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
require 'renkei-vpe-server/server_role'
require 'renkei-vpe-server/logger'
require 'renkei-vpe-server/user'
require 'renkei-vpe-server/user_pool'
require 'renkei-vpe-server/image'
require 'renkei-vpe-server/image_pool'
require 'renkei-vpe-server/zone'
require 'renkei-vpe-server/zone_pool'
require 'renkei-vpe-server/host'
require 'renkei-vpe-server/host_pool'
require 'renkei-vpe-server/virtual_network'
require 'renkei-vpe-server/virtual_network_pool'
require 'renkei-vpe-server/vm_type'
require 'renkei-vpe-server/vm_type_pool'
require 'renkei-vpe-server/virtual_machine'
require 'renkei-vpe-server/virtual_machine_pool'

##############################################################################
# RenkeiVPE module for the server
##############################################################################
module RenkeiVPE

  ############################################################################
  # Renkei VPE server components
  ############################################################################
  class Server
    # Path for log file
    LOG_FILE = $rvpe_path + '/var/rvped.log'
    # Path for database file
    DB_FILE  = $rvpe_path + '/var/rvped.db'

    def initialize(config)
      # initialize logger
      RenkeiVPE::Logger.init(LOG_FILE)
      log = RenkeiVPE::Logger.get_logger
      log.set_level(config.log_level)

      log.info 'Renkei VPE server starts'
      log.info config.to_s

      # initialize database
      RenkeiVPE::Database.init(DB_FILE)

      # initialize one client
      RenkeiVPE::OpenNebulaClient.init(config.one_endpoint)

      # setup xml rpc methods
      rpcms = [
               [User::INTERFACE,               User.new],
               [UserPool::INTERFACE,           UserPool.new],
               [Image::INTERFACE,              Image.new],
               [ImagePool::INTERFACE,          ImagePool.new],
               [Zone::INTERFACE,               Zone.new],
               [ZonePool::INTERFACE,           ZonePool.new],
               [Host::INTERFACE,               Host.new],
               [HostPool::INTERFACE,           HostPool.new],
               [VirtualNetwork::INTERFACE,     VirtualNetwork.new],
               [VirtualNetworkPool::INTERFACE, VirtualNetworkPool.new],
               [VMType::INTERFACE,             VMType.new],
               [VMTypePool::INTERFACE,         VMTypePool.new],
               [VirtualMachine::INTERFACE,     VirtualMachine.new],
               [VirtualMachinePool::INTERFACE, VirtualMachinePool.new],
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
      'log_level' => 'info',
    }

    instance_methods.each do |m|
      undef_method m unless m.to_s =~ /^__|method_missing|respond_to?/
    end

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

      super if !respond_to?(param)
      return @configs[param]
    end

    def respond_to?(method)
      @configs.include?(method.to_s) || super
    end

    def to_s
      line_format = "%15s | %s\n"

      str = "Configuration\n"
      @configs.each do |k,v|
        str += line_format % [k,v]
      end
      return str.chomp
    end
  end

end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
