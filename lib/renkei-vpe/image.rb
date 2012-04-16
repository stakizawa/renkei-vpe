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


require 'renkei-vpe/pool'
require 'OpenNebula'

module RenkeiVPE
  class Image < PoolElement
    # ---------------------------------------------------------------------
    # Constants and Class Methods
    # ---------------------------------------------------------------------
    IMAGE_METHODS = {
      :info        => "image.info",
      :allocate    => "image.allocate",
      :enable      => "image.enable",
      :publish     => "image.publish",
      :persistent  => "image.persistent",
      :description => "image.description",
      :delete      => "image.delete"
    }

    IMAGE_STATES       = OpenNebula::Image::IMAGE_STATES
    SHORT_IMAGE_STATES = OpenNebula::Image::SHORT_IMAGE_STATES

    # Creates an Image description with just its identifier
    # this method should be used to create plain Image objects.
    # +id+ the id of the image
    #
    # Example:
    #   image = Image.new(Image.build_xml(3),rpc_client)
    #
    def Image.build_xml(pe_id=nil)
      if pe_id
        image_xml = "<IMAGE><ID>#{pe_id}</ID></IMAGE>"
      else
        image_xml = "<IMAGE></IMAGE>"
      end

      XMLElement.build_xml(image_xml,'IMAGE')
    end

    # Class constructor
    def initialize(xml, client)
      super(xml,client)

      @client = client
    end

    #######################################################################
    # XML-RPC Methods for the Image Object
    #######################################################################

    # Retrieves the information of the given Image.
    def info()
      super(IMAGE_METHODS[:info], 'IMAGE')
    end

    # Allocates a new Image in RenkeiVPE
    #
    # +description+ A string containing the template of the Image.
    def allocate(description)
      super(IMAGE_METHODS[:allocate],description)
    end

    # Enables an Image
    def enable
      set_enabled(true)
    end

    # Disables an Image
    def disable
      set_enabled(false)
    end

    # Publishes the Image, to be used by other users
    def publish
      set_publish(true)
    end

    # Unplubishes the Image
    def unpublish
      set_publish(false)
    end

    # make the Image persistent
    def persistent
      set_persistent(true)
    end

    # make the Image nonpersistent
    def nonpersistent
      set_persistent(false)
    end

    # Deletes the Image
    def delete()
      super(IMAGE_METHODS[:delete])
    end

    def description(new_desc)
      return Error.new('ID not defined') if !@pe_id

      rc = @client.call(IMAGE_METHODS[:description], @pe_id, new_desc)
      rc = nil if !RenkeiVPE.is_error?(rc)

      return rc
    end

    #######################################################################
    # Helpers to create/delete/export Image
    #######################################################################

    # Register a new image
    def register(description)
      # allocate the image
      result = allocate(description)
      if RenkeiVPE.is_error?(result)
        return result
      end

      # copy the image file
      # TODO it might be better to send file to the server
      result = self.info
      if RenkeiVPE.is_error?(result)
        return result
      end
      if self['TEMPLATE/PATH']
        result = nil
        file_path = self['TEMPLATE/PATH']
        if !File.exist?(file_path)
          error_msg = "Image file could not be found, aborting."
          result = RenkeiVPE::Error.new(error_msg)
        else
          begin
            FileUtils.copy(file_path, self['SOURCE'])
            FileUtils.chmod(0660, self['SOURCE'])
          rescue Exception => e
            result = RenkeiVPE::Error.new(e.message)
          end
        end
      else
        result = RenkeiVPE::Error.new('Failed to copy image file')
      end

      if RenkeiVPE.is_successful?(result)
        self.enable
      else
        self.delete
      end

      return result
    end

    def unregister
      # TODO it might be better to remotely remove image file
      result = self.info

      if RenkeiVPE.is_successful?(result)
        file_path = self['SOURCE']
        result = self.delete
        if RenkeiVPE.is_successful?(result)
          begin
            FileUtils.rm(file_path)
            result = nil
          rescue Exception => e
            result = RenkeiVPE::Error.new(e.message)
          end
        end
      end

      return result
    end

    def export(dirname)
      result = self.info
      if RenkeiVPE.is_successful?(result)
        FileUtils.mkdir_p(dirname)
        disk_file = dirname + '/disk.img'
        attr_file = dirname + '/attr.txt'

        # copy the disk image file
        # TODO download the file from remove server
        FileUtils.cp(self['SOURCE'], disk_file)

        # create the attribute file
        File.open(attr_file, 'w') do |f|
          f.puts <<EOT
name:        #{@name}
description: #{get_template_value('DESCRIPTION')}
public:      NO
io_bus:      #{get_template_value('BUS')}
nic_model:   #{get_template_value('NIC_MODEL')}
path:        ./disk.img
EOT
        end
      end
      return result
    end

    #######################################################################
    # Helpers to get Image information
    #######################################################################

    # Returns the state of the Image (numeric value)
    def state
      self['STATE'].to_i
    end

    # Returns the state of the Image (string value)
    def state_str
      IMAGE_STATES[state]
    end

    # Returns the state of the Image (string value)
    def short_state_str
      SHORT_IMAGE_STATES[state_str]
    end

    # Returns the state of the Image (string value)
    def super_state_str
      if state_str == 'USED'
        vm_cnt_str = self['RUNNING_VMS']
        if vm_cnt_str == '1'
          vm_cnt_str += ' VM'
        else
          vm_cnt_str += ' VMs'
        end
        state_str + ' by ' + vm_cnt_str
      else
        state_str
      end
    end

    # Returns the type of the Image (numeric value)
    def type
      self['TYPE'].to_i
    end

    # Returns the type of the Image (string value)
    def type_str
      IMAGE_TYPES[type]
    end

    # Returns the state of the Image (string value)
    def short_type_str
      SHORT_IMAGE_TYPES[type_str]
    end

    # Returns a template value of the Image (string value)
    def get_template_value(key)
      _key = key.upcase
      self.template_str.each_line do |line|
        if /^#{_key}\s*=\s*(.+)/ =~ line
          return $1
        end
      end
      return ''
    end

    private

    def set_enabled(enabled)
      return Error.new('ID not defined') if !@pe_id

      rc = @client.call(IMAGE_METHODS[:enable], @pe_id, enabled)
      rc = nil if !RenkeiVPE.is_error?(rc)

      return rc
    end

    def set_publish(published)
      return Error.new('ID not defined') if !@pe_id

      rc = @client.call(IMAGE_METHODS[:publish], @pe_id, published)
      rc = nil if !RenkeiVPE.is_error?(rc)

      return rc
    end

    def set_persistent(persistent)
      return Error.new('ID not defined') if !@pe_id

      rc = @client.call(IMAGE_METHODS[:persistent], @pe_id, persistent)
      rc = nil if !RenkeiVPE.is_error?(rc)

      return rc
    end
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
