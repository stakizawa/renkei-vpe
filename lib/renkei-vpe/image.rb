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

        # Deletes the Image
        def delete()
            super(IMAGE_METHODS[:delete])
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
                file_path = self['TEMPLATE/PATH']
                if !File.exist?(file_path)
                    error_msg = "Image file could not be found, aborting."
                    result = RenkeiVPE::Error.new(error_msg)
                end

                begin
                    FileUtils.copy(file_path, self['SOURCE'])
                    FileUtils.chmod(0660, self['SOURCE'])
                rescue Exception => e
                    result = RenkeiVPE::Error.new(e.message)
                end
              result = nil
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

        def export(filename)
            # TODO it might be better to download the file from remove server
            result = self.info
            if RenkeiVPE.is_successful?(result)
                FileUtils.cp(self['SOURCE'], filename)
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
    end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
