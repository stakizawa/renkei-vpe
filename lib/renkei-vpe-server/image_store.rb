module RenkeiVPE
  module ImageStore

    # It does gfarm-replicate by a specified interval to create enough
    # number of image replicas.
    class GfarmReplicate
      def initialize(config)
        @gfrep = config.gfarm_location + '/bin/gfrep'
        @img_dir = config.gfarm_local_path
        @n_replicas = config.gfarm_replica_count
        @interval = config.gfarm_replicate_interval.to_i
      end

      def serve
        @exec_f = true
        log = RenkeiVPE::Logger.get_logger

        loop do
          if @exec_f
            output = `#{@gfrep} -N #{@n_replicas} #{@img_dir} 2>&1`
            output.each_line do |line|
              log.info line.chomp
            end

            break unless @exec_f
          else
            break
          end

          @sleep_t = Thread.new do
            sleep @interval
          end
          @sleep_t.join
          @sleep_t = nil
        end
      end

      def shutdown
        @exec_f = false
        @sleep_t.run if @sleep_t
      end
    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
