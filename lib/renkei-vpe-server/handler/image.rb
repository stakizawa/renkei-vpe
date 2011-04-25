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
          admin_session(session) { flag = -2 }
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
          call_one_xmlrpc('one.image.allocate', session, template)
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
          call_one_xmlrpc('one.image.publish', session, id, published)
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
