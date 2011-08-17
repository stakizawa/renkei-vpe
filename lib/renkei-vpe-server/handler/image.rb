require 'renkei-vpe-server/handler/base'

module RenkeiVPE
  module Handler

    class ImageHandler < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.image') do
        meth('val pool(string, int)',
             'Retrieve information about image group',
             'pool')
        meth('val ask_id(string, string)',
             'Retrieve id of the given-named image',
             'ask_id')
        meth('val info(string, int)',
             'Retrieve information about the image',
             'info')
        meth('val allocate(string, string)',
             'Allocates a new image',
             'allocate')
        meth('val delete(string, int)',
             'Deletes an image from the image pool',
             'delete')
        meth('val enable(string, int, bool)',
             'Enables or disables an image',
             'enable')
        meth('val publish(string, int, bool)',
             'Publishes or unpublishes an image',
             'publish')
        meth('val persistent(string, int, bool)',
             'make an image persistent or nonpersistent',
             'persistent')
        meth('val description(string, int, string)',
             'Update description of an image',
             'description')
      end


      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # return information about image group.
      # +session+   string that represents user session
      # +flag+      flag for condition
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the information string
      def pool(session, flag)
        task('rvpe.image.pool', session) do
          if flag <= -2 || flag >= 0
            admin_session(session) do; end
          else # flag == -1
          end

          call_one_xmlrpc('one.imagepool.info', session, flag)
        end
      end

      # return id of the given-named image.
      # +session+   string that represents user session
      # +name+      name of an image
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the id of the image
      def ask_id(session, name)
        task('rvpe.image.ask_id', session) do
          flag = -1
          admin_session(session, false) { flag = -2 }
          rc = call_one_xmlrpc('one.imagepool.info', session, flag)
          raise rc[1] unless rc[0]

          id = nil
          doc = REXML::Document.new(rc[1])
          doc.elements.each('IMAGE_POOL/IMAGE') do |e|
            db_name = e.elements['NAME'].get_text
            if db_name == name
              id = e.elements['ID'].get_text.to_s.to_i
              break
            end
          end
          raise "Image[#{name}] is not found. " unless id

          [true, id]
        end
      end

      # return information about this image.
      # +session+   string that represents user session
      # +id+        id of the image
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the string with the information
      #             about the image
      def info(session, id)
        task('rvpe.image.info', session) do
          call_one_xmlrpc('one.image.info', session, id)
        end
      end

      # allocates a new image.
      # +session+   string that represents user session
      # +template+  a string containing the template of the image
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is the error message,
      #             if successful this is the associated id (int id)
      #             generated for this image
      def allocate(session, template)
        task('rvpe.image.allocate', session) do
          image_def = ResourceFile::Parser.load_yaml(template)
          # check fields
          err_msg_suffix = ' in Image file.'
          _name = image_def[ResourceFile::Image::NAME]
          unless _name
            raise 'Specify ' + ResourceFile::Image::NAME + err_msg_suffix
          end
          _type = image_def[ResourceFile::Image::TYPE]
          _type = 'OS' unless _type
          if image_def[ResourceFile::Image::PUBLIC] &&
              image_def[ResourceFile::Image::PERSISTENT]
            raise "An image can't be public and persistent at the same time."
          end
          _public = image_def[ResourceFile::Image::PUBLIC]
          if _public
            _public = 'YES' # yaml automatically converted 'YES' to true
          else
            _public = 'NO'
          end
          _persistent = image_def[ResourceFile::Image::PERSISTENT]
          if _persistent
            _persistent = 'YES' # yaml automatically converted 'YES' to true
          else
            _persistent = 'NO'
          end
          _bus = image_def[ResourceFile::Image::IO_BUS]
          _bus = 'virtio' unless _bus
          case _bus.downcase
          when 'virtio'
            _dev_prefix = 'vd'
          when 'ide'
            _dev_prefix = 'hd'
          else
            _dev_prefix = 'sd'
          end
          _path = image_def[ResourceFile::Image::PATH]
          unless _path
            raise 'Specify ' + ResourceFile::Image::PATH + err_msg_suffix
          end
          _nic_model = image_def[ResourceFile::Image::NIC_MODEL]
          _nic_model = 'virtio' unless _nic_model

          one_template = <<EOT
NAME        = "#{_name}"
DESCRIPTION = "#{image_def[ResourceFile::Image::DESCRIPTION]}"
TYPE        = "#{_type}"
PUBLIC      = "#{_public}"
PERSISTENT  = "#{_persistent}"
BUS         = "#{_bus}"
DEV_PREFIX  = "#{_dev_prefix}"
NIC_MODEL   = "#{_nic_model}"
PATH        = "#{_path}"
EOT

          call_one_xmlrpc('one.image.allocate', session, one_template)
        end
      end

      # deletes an image from the image pool.
      # +session+   string that represents user session
      # +id+        id of the image
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def delete(session, id)
        task('rvpe.image.delete', session) do
          call_one_xmlrpc('one.image.delete', session, id)
        end
      end

      # enables or disables an image
      # +session+   string that represents user session
      # +id+        id of the image
      # +enabled+   true for enabling, false for disabling
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it is the image id.
      def enable(session, id, enabled)
        task('rvpe.image.enable', session) do
          call_one_xmlrpc('one.image.enable', session, id, enabled)
        end
      end

      # publishes or unpublishes an image.
      # +session+   string that represents user session
      # +id+        id of the image
      # +published+ true for publishing, false for unpublishing
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it is the image id.
      def publish(session, id, published)
        task('rvpe.image.publish', session) do
          rc = call_one_xmlrpc('one.image.publish', session, id, published)
          raise "A persistent image can't be public." unless rc[0]
          rc
        end
      end

      # make an image persistent or nonpersistent.
      # +session+   string that represents user session
      # +id+        id of the image
      # +persistent+ true for persistent, false for nonpersistent
      # +return[0]+  true or false whenever is successful or not
      # +return[1]+  if an error occurs this is error message,
      #              otherwise it is the image id.
      def persistent(session, id, persistent)
        task('rvpe.image.persistent', session) do
          rc = call_one_xmlrpc('one.image.persistent', session, id, persistent)
          raise "A public image can't be persistent." unless rc[0]
          rc
        end
      end

      # update description of an image.
      # +session+         string that represents user session
      # +id+              id of the image
      # +new_description+ new description of the image
      def description(session, id, new_description)
        task('rvpe.image.description', session) do
          call_one_xmlrpc('one.image.update', session, id,
                          'DESCRIPTION', new_description)
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
