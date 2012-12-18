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


module RenkeiVPE
  module ImageStore

    # It does gfarm-replicate by a specified interval to create enough
    # number of image replicas.
    class GfarmReplicate
      def initialize(config)
        @gfrep = config.gfarm_location + '/bin/gfrep'
        @img_dir = config.gfarm_local_path
        @n_replicas = config.gfarm_replica_count
        @interval = config.gfarm_replicate_interval
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
