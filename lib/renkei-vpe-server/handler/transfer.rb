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


require 'renkei-vpe-server/handler/base'
require 'digest/sha1'

module RenkeiVPE
  module Handler

    class TransferHandler < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.transfer') do
        meth('val init(string, string, int)',
             'Initialize transfer session',
             'init')
        meth('val put(string, string, string, string)',
             'Put data on RENKEI-VPE',
             'put')
        meth('val get(string, string, int)',
             'Get data from RENKEI-VPE',
             'get')
        meth('val finalize(string, string)',
             'Finalize transfer session',
             'finalize')
        meth('val cancel(string, string)',
             'cancel transfer session',
             'cancel')
        meth('val delete(string, string)',
             'delete data from RENKEI-VPE',
             'delete')
      end

      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # initialize transfer session.
      # +session+      string that represents user session
      # +type+         string that represents transfer type.
      #                it should be 'put' or 'get'.
      # +session_seed+ string used for creating transfer session
      # +file_size+    integer that represents file size.
      #                It makes sense when type is 'put'.
      # +return[0]+    true or false whenever is successful or not
      # +return[1]+    if an error occurs this is error message,
      #                if successful this is the string that represents the
      #                information about transfer
      def init(session, type, session_seed, file_size)
        write_task('rvpe.transfer.init', session) do
          user = get_user_from_session(session)
          ts_name = Digest::SHA1.hexdigest("#{user}#{Time.now}#{session_seed}")

          if type == 'put'
            path = transfer_storage + '/' + ts_name
          elsif type == 'get'
            path = session_seed
            unless FileTest.exist?(path)
              raise "File[#{path}] does not exist in RENKEI-VPE."
            end
            file_size = File.size(path)
          else
            raise "Unknown transfer type: #{type}"
          end

          # create transfer session
          t = Transfer.new
          t.name = ts_name
          t.type = type
          t.path = path
          t.size = file_size
          t.create

          # add CHUNK_SIZE
          t_e = t.to_xml_element
          cnk_e = REXML::Element.new('CHUNK_SIZE')
          cnk_e.add(REXML::Text.new($server_config.transfer_chunk_size.to_s))
          t_e.add(cnk_e)

          doc = REXML::Document.new
          doc.add(t_e)
          @log.info "TransferSession[#{t.name}] is created."
          [true, doc.to_s]
        end
      end

      # put data on the server.
      # +session+          string that represents user session
      # +transfer_session+ string that represents transfer session
      # +data+             string data contains data
      # +return[0]+        true or false whenever is successful or not
      # +return[1]+        if an error occurs this is error message,
      #                    otherwise it does not exist.
      def put(session, transfer_session, data)
        read_task('rvpe.transfer.put', session) do
          t = Transfer.find_by_name(transfer_session)[0]
          raise 'Transfer has been already done.' if t.is_done?

          File.open(t.path, 'ab') do |f|
            f.flock(File::LOCK_EX)
            f.write(XMLRPC::Base64.decode(data))
            f.flock(File::LOCK_UN)
          end
          @log.info "A part of File[#{t.path}] is successfully transfered in TransferSession[#{t.name}]."
          [true, '']
        end
      end

      # get data from the server.
      # +session+          string that represents user session
      # +transfer_session+ string that represents transfer session
      # +offset+           integer that represents offset of file
      # +return[0]+        true or false whenever is successful or not
      # +return[1]+        if an error occurs this is error message,
      #                    otherwise it is data
      def get(session, transfer_session, offset)
        read_task('rvpe.transfer.get', session) do
          t = Transfer.find_by_name(transfer_session)[0]
          raise 'Transfer has been already done.' if t.is_done?

          data = ''
          File.open(t.path, 'rb') do |f|
            f.seek(offset)
            raw_data = f.read($server_config.transfer_chunk_size)
            if raw_data
              data = XMLRPC::Base64.encode(raw_data)
            end
          end
          @log.info "A part of File[#{t.path}] is successfully transfered in TransferSession[#{t.name}]."
          [true, data]
        end
      end

      # finalize specified transfer session.
      # +session+          string that represents user session
      # +transfer_session+ string that represents transfer session
      # +return[0]+        true or false whenever is successful or not
      # +return[1]+        if an error occurs this is error message,
      #                    otherwise it does not exist.
      def finalize(session, transfer_session)
        write_task('rvpe.transfer.finalize', session) do
          t = Transfer.find_by_name(transfer_session)[0]
          raise 'Transfer has been already done.' if t.is_done?
          t.set_done

          if t.type == 'put'
            if File.size(t.path) != t.size
              FileUtils.rm_rf(t.path)
              raise 'Transfer failed: File size is not same.'
            end
          end
          @log.info "TransferSession[#{t.name}] is successfully done."
          [true, '']
        end
      end

      # cancel specified transfer session.
      # +session+          string that represents user session
      # +transfer_session+ string that represents transfer session
      # +return[0]+        true or false whenever is successful or not
      # +return[1]+        if an error occurs this is error message,
      #                    otherwise it does not exist.
      def cancel(session, transfer_session)
        write_task('rvpe.transfer.finalize', session) do
          t = Transfer.find_by_name(transfer_session)[0]
          FileUtils.rm_rf(t.path) if t.type == 'put'
          t.delete
          @log.info "TransferSession[#{t.name}] is canceled."
          [true, '']
        end
      end

      # delete data from the server.
      # +session+    string that represents user session
      # +file_path+  string that represents path of target file
      # +return[0]+  true or false whenever is successful or not
      # +return[1]+  if an error occurs this is error message,
      #              otherwise it does not exist.
      def delete(session, file_path)
        read_task('rvpe.transfer.delete', session) do
          unless FileTest.exist?(file_path)
            raise "File[#{file_path}] does not exist."
          end
          FileUtils.rm(file_path)
          @log.info "File[#{file_path}] is deleted."
          [true, '']
        end
      end


      # It cleans up transfer sessions.
      # It deletes old transfer records from transfers table and deletes
      # forgotten to be delete files in 'transfer_storage' directory.
      class Cleaner
        def initialize(config)
          @session_life_time = config.transfer_session_life_time
          @interval = 3600 # 1h
        end

        def serve
          @exec_f = true
          log = RenkeiVPE::Logger.get_logger

          loop do
            if @exec_f
              ts = RenkeiVPE::Model::Transfer.cleanup_before(@session_life_time)
              ts.each do |t|
                if t.type == 'put' && FileTest.exist?(t.path)
                  FileUtils.rm(t.path)
                  log.info "Stale File[#{t.path}] is deleted."
                end
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

      private

      @transfer_storage = nil
      def transfer_storage
        unless @transfer_storage
          @transfer_storage = $server_config.gfarm_mount_point +
            '/temporal_transfer'
          unless FileTest.exist?(@transfer_storage)
            FileUtils.mkdir_p(@transfer_storage)
          end
        end
        @transfer_storage
      end

    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
