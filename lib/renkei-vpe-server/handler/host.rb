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

module RenkeiVPE
  module Handler

    class HostHandler < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.host') do
        meth('val pool(string)',
             'Retrieve information about host group',
             'pool')
        meth('val ask_id(string, string)',
             'Retrieve id of the given-named host',
             'ask_id')
        meth('val info(string, int)',
             'Retrieve information about the host',
             'info')
        meth('val enable(string, int, bool)',
             'Enables or disables a host',
             'enable')
      end


      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # return information about host group.
      # +session+   string that represents user session
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the information string
      def pool(session)
        read_task('rvpe.host.pool', session) do
          call_one_xmlrpc('one.hostpool.info', session)
        end
      end

      # return id of the given-named host.
      # +session+   string that represents user session
      # +name+      name of a host
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the id of the host
      def ask_id(session, name)
        read_task('rvpe.host.ask_id', session) do
          rc = call_one_xmlrpc('one.hostpool.info', session)
          raise rc[1] unless rc[0]

          id = nil
          doc = REXML::Document.new(rc[1])
          doc.elements.each('HOST_POOL/HOST') do |e|
            db_name = e.elements['NAME'].get_text
            if db_name == name
              id = e.elements['ID'].get_text.to_i
              break
            end
          end
          raise "Host[#{name}] is not found. " unless id

          [true, id]
        end
      end

      # return information about this host.
      # +session+   string that represents user session
      # +id+        id of the host
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the string with the information
      #             about the host
      def info(session, id)
        read_task('rvpe.host.info', session) do
          call_one_xmlrpc('one.host.info', session, id)
        end
      end

      # enables or disables a host
      # +session+   string that represents user session
      # +id+        id of the target host
      # +enabled+   true for enabling, false for disabling
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def enable(session, id, enabled)
        write_task('rvpe.host.enable', session, true) do
          call_one_xmlrpc('one.host.enable', session, id, enabled)
        end
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
