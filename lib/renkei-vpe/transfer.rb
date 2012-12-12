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


require 'rubygems'
require 'ruby-progressbar'

require 'renkei-vpe/pool'

module RenkeiVPE
  class Transfer < XMLElement
    # ---------------------------------------------------------------------
    # Constants and Class Methods
    # ---------------------------------------------------------------------
    TRANSFER_METHODS = {
      :init     => "transfer.init",
      :put      => "transfer.put",
      :get      => "transfer.get",
      :finalize => "transfer.finalize",
      :cancel   => "transfer.cancel",
      :delete   => "transfer.delete",
    }

    def initialize(client)
      super
      @client = client
    end

    #######################################################################
    # XML-RPC Methods for the Image Object
    #######################################################################

    def init(type, session_seed, size)
      rc = @client.call(TRANSFER_METHODS[:init], type, session_seed, size)
      if RenkeiVPE.is_successful?(rc)
        initialize_xml(rc, 'TRANSFER')
        return [ self['NAME'], self['SIZE'].to_i, self['CHUNK_SIZE'].to_i ]
      else
        return rc
      end
    end

    def put(transfer_session, raw_data)
      data = XMLRPC::Base64.encode(raw_data)
      rc = @client.call(TRANSFER_METHODS[:put], transfer_session, data)
      if RenkeiVPE.is_successful?(rc)
        return nil
      else
        return rc
      end
    end

    def get(transfer_session, offset)
      rc = @client.call(TRANSFER_METHODS[:get], transfer_session, offset)
      if RenkeiVPE.is_successful?(rc)
        return XMLRPC::Base64.decode(rc)
      else
        return rc
      end
    end

    def finalize(transfer_session)
      rc = @client.call(TRANSFER_METHODS[:finalize], transfer_session)
      if RenkeiVPE.is_successful?(rc)
        return nil
      else
        return rc
      end
    end

    def cancel(transfer_session)
      rc = @client.call(TRANSFER_METHODS[:cancel], transfer_session)
      if RenkeiVPE.is_successful?(rc)
        return nil
      else
        return rc
      end
    end

    def delete(file_path)
      rc = @client.call(TRANSFER_METHODS[:delete], file_path)
      if RenkeiVPE.is_successful?(rc)
        return nil
      else
        return rc
      end
    end

    #######################################################################
    # Helpers to transfer file
    #######################################################################

    # It puts file on the server.
    # It will return name of transfer session when it successfully puts
    # file. Otherwise, it returns RenkeiVPE::Error.
    def transfer_put(filename)
      unless FileTest.exist?(filename)
        return RenkeiVPE::Error.new("File[#{filename}] does not exist.")
      end
      filesize = File.size(filename)

      result = init('put', filename, filesize)
      if RenkeiVPE.is_error?(result)
        return result
      end
      session, filesize, chunk_size = result

      File.open(filename, 'rb') do |f|
        pbar = ProgressBar.create(:title => 'Transfer', :output => STDERR,
                                  :format => '%t(%p%%): |%B|')
        count = filesize / chunk_size + 1
        unit = 100.0 / count

        begin
          data = f.read(chunk_size)
          if data
            result = put(session, data)
            if RenkeiVPE.is_error?(result)
              cancel(session)
              pbar.stop
              return result
            end
            update_progress(pbar, unit)
          end
        end while data != nil
        pbar.finish
      end

      result = finalize(session)
      if RenkeiVPE.is_error?(result)
        return result
      end
      return session
    end

    def transfer_get(remote_filename, local_filename)
      if FileTest.exist?(local_filename)
        return RenkeiVPE::Error.new("File[#{local_filename}] exists.")
      end

      result = init('get', remote_filename, -1)
      if RenkeiVPE.is_error?(result)
        return result
      end
      session, filesize, chunk_size = result

      File.open(local_filename, 'ab') do |f|
        pbar = ProgressBar.create(:title => 'Transfer', :output => STDERR,
                                  :format => '%t(%p%%): |%B|')
        count = filesize / chunk_size + 1
        unit = 100.0 / count

        offset = 0
        begin
          result = get(session, offset)
          if RenkeiVPE.is_error?(result)
            cancel(session)
            pbar.stop
            f.close
            FileUtils.rm_rf(local_filename)
            return result
          end
          f.write(result)
          offset += result.size
          update_progress(pbar, unit)
        end while offset < filesize
        pbar.finish
      end

      result = finalize(session)
      if RenkeiVPE.is_error?(result)
        return result
      end
      return nil
    end

    private

    def update_progress(pbar, val)
      tmp = pbar.progress
      tmp += val
      if tmp <= 100
        pbar.progress = tmp
      else
        pbar.progress = 100
      end
    end

  end
end

# Modify output of progressbar
class ProgressBar
  module Components::Progressable
    def percentage_completed
      return 100 if total == 0
      (self.progress * 100 / total).ceil
    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
