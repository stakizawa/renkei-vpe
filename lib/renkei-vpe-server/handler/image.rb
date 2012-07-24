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
        read_task('rvpe.image.pool', session) do
          if flag <= -2 || flag >= 0
            admin_session(session) do; end
          else # flag == -1
          end

          rc = call_one_xmlrpc('one.imagepool.info', session, flag)
          raise rc[1] unless rc[0]
          doc = weave_image_size_to_xml(rc[1], 'IMAGE_POOL/')
          [true, doc.to_s]
        end
      end

      # return id of the given-named image.
      # +session+   string that represents user session
      # +name+      name of an image
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the id of the image
      def ask_id(session, name)
        read_task('rvpe.image.ask_id', session) do
          flag = -1
          admin_session(session, false) { flag = -2 }
          img = Image.find_by_name(name, session, flag).last
          raise "Image[#{name}] is not found. " unless img

          [true, img.id]
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
        read_task('rvpe.image.info', session) do
          rc = call_one_xmlrpc('one.image.info', session, id)
          raise rc[1] unless rc[0]

          unless image_is_public?(rc[1])
            unless image_is_owned_by_session_owner?(rc[1], session)
              msg = "You don't have permission to access the image."
              admin_session(session, true, msg) do; end
            end
          end

          doc = weave_image_size_to_xml(rc[1])
          [true, doc.to_s]
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
        write_task('rvpe.image.allocate', session) do
          image_def = ResourceFile::Parser.load_yaml(template)
          # check fields
          err_msg_suffix = ' in Image file.'
          _name = image_def[ResourceFile::Image::NAME]
          unless _name
            raise 'Specify ' + ResourceFile::Image::NAME + err_msg_suffix
          end
          unless Image.find_by_name(_name, session, -2).empty?
            raise "Image[#{_name}] already exists.  Use another name."
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
        write_task('rvpe.image.delete', session) do
          err_msg = "You don't have permission to delete the image."
          sanity_check(session, id, err_msg) do
            call_one_xmlrpc('one.image.delete', session, id)
          end
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
        write_task('rvpe.image.enable', session) do
          err_msg = "You don't have permission to enable/disable the image."
          sanity_check(session, id, err_msg) do
            call_one_xmlrpc('one.image.enable', session, id, enabled)
          end
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
        write_task('rvpe.image.publish', session) do
          err_msg = "You don't have permission to publish/unpublish the image."
          sanity_check(session, id, err_msg) do
            rc = call_one_xmlrpc('one.image.publish', session, id, published)
            raise "A persistent image can't be public." unless rc[0]
            rc
          end
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
        write_task('rvpe.image.persistent', session) do
          err_msg = "You don't have permission to make the image persistent."
          sanity_check(session, id, err_msg) do
            rc = call_one_xmlrpc('one.image.persistent',
                                 session, id, persistent)
            raise "A public or used image can't be persistent." unless rc[0]
            rc
          end
        end
      end

      # update description of an image.
      # +session+         string that represents user session
      # +id+              id of the image
      # +new_description+ new description of the image
      def description(session, id, new_description)
        write_task('rvpe.image.description', session) do
          err_msg = "You don't have permission to modify the description " +
            'of the image.'
          sanity_check(session, id, err_msg) do
            call_one_xmlrpc('one.image.update', session, id,
                            'DESCRIPTION', new_description)
          end
        end
      end

      private

      # It checks the image access permission.
      def sanity_check(session, id, err_msg=nil)
        rc = call_one_xmlrpc('one.image.info', session, id)
        raise rc[1] unless rc[0]
        unless image_is_owned_by_session_owner?(rc[1], session)
          admin_session(session, true, err_msg) do; end
        end
        yield rc[1]
      end

      # It weaves 'SIZE' element that represents image size to the
      # specified xml string.
      def weave_image_size_to_xml(xmlstr, xpath_prefix='')
        doc = REXML::Document.new(xmlstr)
        doc.elements.each(xpath_prefix + 'IMAGE') do |img_e|
          img_file_path = nil
          img_e.each_element('SOURCE') do |src_e|
            img_file_path = src_e.get_text.to_s
          end # img_file_path must not be nil
          size_e = REXML::Element.new('SIZE')
          if FileTest.exist?(img_file_path)
            text = File.size(img_file_path).to_s
          else
            text = '-'
          end
          size_e.add(REXML::Text.new(text))
          img_e.add(size_e)
        end
        doc
      end

      # It return true if the image is public.
      def image_is_public?(xmlstr)
        pblc = false
        doc = REXML::Document.new(xmlstr)
        doc.elements.each('IMAGE') do |img_e|
          img_e.each_element('PUBLIC') do |pub_e|
            pub_f = pub_e.get_text.to_s.to_i
            pblc = true if pub_f == 1
          end
        end
        pblc
      end

      # It returns true if the image represented by __xmlstr__ is owned by
      # the __session__ owner.
      def image_is_owned_by_session_owner?(xmlstr, session)
        uname = get_user_from_session(session)
        user = User.find_by_name(uname).last

        uid = -1
        doc = REXML::Document.new(xmlstr)
        doc.elements.each('IMAGE') do |img_e|
          img_e.each_element('UID') do |uid_e|
            uid = uid_e.get_text.to_s.to_i
          end # uid must not be -1
        end

        if uid == user.oid
          true
        else
          false
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
