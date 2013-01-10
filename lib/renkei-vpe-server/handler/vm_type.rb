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
require 'renkei-vpe-server/resource_file'
require 'rexml/document'

module RenkeiVPE
  module Handler

    class VMTypeHandler < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.vmtype') do
        meth('val pool(string)',
             'Retrieve information about vm type group',
             'pool')
        meth('val ask_id(string, string)',
             'Retrieve id of the given-named vm type',
             'ask_id')
        meth('val info(string, int)',
             'Retrieve information about the vm type',
             'info')
        meth('val allocate(string, string)',
             'Allocates a new vm type',
             'allocate')
        meth('val delete(string, int)',
             'Deletes a vm type from the vm type pool',
             'delete')
      end

      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # return information about vm type group.
      # +session+   string that represents user session
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the information string
      def pool(session)
        read_task('rvpe.vmtype.pool', session) do
          pool_e = REXML::Element.new('VMTYPE_POOL')
          VMType.each do |type|
            type_e = type.to_xml_element
            pool_e.add(type_e)
          end
          doc = REXML::Document.new
          doc.add(pool_e)
          [true, doc.to_s]
        end
      end

      # return id of the given-named vm type.
      # +session+   string that represents user session
      # +name+      name of a vm type
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the id of the vm type
      def ask_id(session, name)
        read_task('rvpe.vmtype.ask_id', session) do
          t = VMType.find_by_name(name).last
          raise "VMType[#{name}] is not found. " unless t

          [true, t.id]
        end
      end

      # return information about this vm type.
      # +session+   string that represents user session
      # +id+        id of the user
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the string with the information
      #             about the user
      def info(session, id)
        read_task('rvpe.vmtype.info', session) do
          type = VMType.find_by_id(id)[0]
          raise "VMType[#{id}] is not found." unless type

          type_e = type.to_xml_element
          doc = REXML::Document.new
          doc.add(type_e)

          [true, doc.to_s]
        end
      end

      # allocates a new vm type.
      # +session+   string that represents user session
      # +template+  a string containing the template of the vm type
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is the error message,
      #             if successful this is the associated id (int uid)
      #             generated for this vm type
      def allocate(session, template)
        write_task('rvpe.vmtype.allocate', session, true) do
          type_def = ResourceFile::Parser.load_yaml(template)

          # check fields
          err_msg_suffix = ' in VM Type file.'
          # check name
          name = type_def[ResourceFile::VMType::NAME]
          unless name
            raise 'Specify ' + ResourceFile::VMType::NAME + err_msg_suffix
          end
          type = VMType.find_by_name(name).last
          raise "VMType[#{name}] already exists." if type
          # check cpu
          cpu = type_def[ResourceFile::VMType::CPU]
          unless cpu
            raise 'Specify ' + ResourceFile::VMType::CPU + err_msg_suffix
          end
          unless /^\d+$/ =~ cpu.to_s
            raise 'Format error of ' + ResourceFile::VMType::CPU +
              err_msg_suffix + '  Its value should be digits.'
          end
          # check memory
          memory = type_def[ResourceFile::VMType::MEMORY]
          unless memory
            raise 'Specify ' + ResourceFile::VMType::MEMORY + err_msg_suffix
          end
          unless /^\d+$/ =~ memory.to_s
            raise 'Format error of ' + ResourceFile::VMType::MEMORY +
              err_msg_suffix + '  Its value should be digits.'
          end

          type = VMType.new
          type.name        = name
          type.cpu         = cpu
          type.memory      = memory
          type.description = type_def[ResourceFile::VMType::DESCRIPTION]
          type.create

          [true, type.id]
        end
      end

      # deletes a vm type.
      # +session+   string that represents user session
      # +id+        id for the vm type we want to delete
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def delete(session, id)
        write_task('rvpe.vmtype.delete', session, true) do
          type = VMType.find_by_id(id)[0]
          raise "VMType[#{id}] does not exist." unless type

          type.delete
          [true, '']
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
