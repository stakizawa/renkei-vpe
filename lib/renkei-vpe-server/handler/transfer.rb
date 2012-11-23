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
      end

      ########################################################################
      # Setup temporal data storage
      ########################################################################
      TEMP_DIR = $rvpe_path + '/var/transfer'  # TODO read from config
      unless FileTest.exist?(TEMP_DIR)
        FileUtils.mkdir_p(TEMP_DIR)
      end

      # TODO read chunk size from config
      CHUNK_SIZE = '16777216'   # 16MB
#      CHUNK_SIZE = '67108864'   # 64MB

      # session store for transfer
      # TODO use database
      class TransferSession
        def initialize
          @sessions = {}
        end

        def add_new(name, type, size, path)
          s = { :type => type, :size => size, :path => path, :done => false }
          @sessions[name] = s
        end

        def get_type(name)
          @sessions[name][:type]
        end

        def get_size(name)
          @sessions[name][:size]
        end

        def get_path(name)
          @sessions[name][:path]
        end

        def get_state(name)
          @sessions[name][:done]
        end

        def set_state(name, flag)
          @sessions[name][:done] = flag
        end

        def self.instance
          return @ts if @ts
          @ts = TransferSession.new
          return @ts
        end
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
            path = TEMP_DIR + '/' + ts_name
          elsif type == 'get'
            path = session_seed
            unless FileTest.exist?(path)
              raise "File[#{path}] does not exist in RENKEI-VPE."
            end
            file_size = File.size(path)
          else
            raise "Unknown transfer type: #{type}"
          end

          # TODO fix from here to use model
          ts = TransferSession.instance
          ts.add_new(ts_name, type, file_size, path)
          ts_e = REXML::Element.new('TRANSFER')
          name_e = REXML::Element.new('NAME')
          name_e.add(REXML::Text.new(ts_name))
          ts_e.add(name_e)
          size_e = REXML::Element.new('SIZE')
          size_e.add(REXML::Text.new(file_size.to_s))
          ts_e.add(size_e)
          # TODO read chunk size from config
          cnk_e = REXML::Element.new('CHUNK_SIZE')
          cnk_e.add(REXML::Text.new(CHUNK_SIZE))
          ts_e.add(cnk_e)

          doc = REXML::Document.new
          doc.add(ts_e)
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
          # TODO fix here to use model
          ts = TransferSession.instance
          if ts.get_state(transfer_session)
            raise 'Transfer has been already done.'
          end
          file_path = ts.get_path(transfer_session)

          File.open(file_path, 'ab') do |f|
            f.flock(File::LOCK_EX)
            f.write(XMLRPC::Base64.decode(data))
            f.flock(File::LOCK_UN)
          end
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
          # TODO fix here to use model
          ts = TransferSession.instance
          if ts.get_state(transfer_session)
            raise 'Transfer has been already done.'
          end
          file_path = ts.get_path(transfer_session)

          data = ''
          File.open(file_path, 'rb') do |f|
            f.seek(offset)
            # TODO read chunk size from config
            raw_data = f.read(CHUNK_SIZE.to_i)
            if raw_data
              data = XMLRPC::Base64.encode(raw_data)
            end
          end
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
          # TODO fix here to use model
          ts = TransferSession.instance
          ts.set_state(transfer_session, true)

          if ts.get_type(transfer_session) == 'put'
            # TODO fix here to use model
            file_path = ts.get_path(transfer_session)
            file_size = ts.get_size(transfer_session)

            if File.size(file_path) != file_size
              FileUtils.rm_rf(file_path)
              raise 'Transfer failed: File size is not same.'
            end
          end
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
          # TODO fix here to use model
          ts = TransferSession.instance
          ts.set_state(transfer_session, true)

          if ts.get_type(transfer_session) == 'put'
            # TODO fix here to use model
            file_path = ts.get_path(transfer_session)

            FileUtils.rm_rf(file_path)
          end
          [true, '']
        end
      end

    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
