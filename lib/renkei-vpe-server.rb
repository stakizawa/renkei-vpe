##############################################################################
# Environment Configuration
##############################################################################
# obtain Renkei-VPE path
$rvpe_path = File.dirname(File.dirname(File.expand_path(__FILE__)))

##############################################################################
# Load libraries
##############################################################################
require 'xmlrpc/server'
require 'yaml'
require 'pp'

require 'renkei-vpe-common'
require 'renkei-vpe-server/logger'
require 'renkei-vpe-server/model'
require 'renkei-vpe-server/handler'
require 'renkei-vpe-server/image_store'

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
      $server_config = config

      # initialize logger
      RenkeiVPE::Logger.init(LOG_FILE)
      log = RenkeiVPE::Logger.get_logger
      log.set_level(config.log_level)

      log.info 'Renkei VPE server starts'
      log.info config.to_s

      # set library path for OpenNebula
      $: << config.one_location + '/lib/ruby'

      # initialize one client
      RenkeiVPE::OpenNebulaClient.init(config.one_endpoint)

      # initialize database
      RenkeiVPE::Model.init(DB_FILE)

      # setup xml rpc server
      @server = XMLRPC::Server.new(config.port)
      RenkeiVPE::Handler.init(@server)

      # setup gfarm replication
      @gfrep = RenkeiVPE::ImageStore::GfarmReplicate.new(config)
    end

    def start
      rpc_t = Thread.new do
        @server.serve
      end
      gfrep_t = Thread.new do
        @gfrep.serve
      end

      signals = [:INT, :TERM, :HUP]
      signals.each do |signal|
        Signal.trap(signal) do
          shutdown
        end
      end

      rpc_t.join
      gfrep_t.join
    end

    def shutdown
      @server.shutdown
      @gfrep.shutdown
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
      'one_location' => ENV['ONE_LOCATION'],
      'one_endpoint' => 'http://localhost:2633/RPC2',
      'gfarm_location' => '/usr',
      'gfarm_local_path' => '/work/one_images',
      'gfarm_replica_count' => '3',
      'gfarm_replicate_interval' => '3600',
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
      line_format = "%25s | %s\n"

      str = "Configuration\n"
      @configs.keys.sort.each do |k|
        str += line_format % [k, @configs[k]]
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
