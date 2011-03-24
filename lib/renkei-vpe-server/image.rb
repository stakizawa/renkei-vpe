require 'xmlrpc/client'
require 'pp'

module RenkeiVPEServer
  class Image
    def initialize(one_endpoint)
      @client = XMLRPC::Client.new2(one_endpoint)
    end

    # return information about this image.
    # +session+   string that represents user session
    # +id+        id of the image
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the string with the information
    #             about the image
    def info(session, id)
      @client.call_async('one.image.info', session, id)
    end

    # allocates a new image.
    # +session+   string that represents user session
    # +template+  a string containing the template of the image
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is the error message,
    #             if successful this is the associated id (int id)
    #             generated for this image
    def allocate(session, template)
      @client.call_async('one.image.allocate', session, template)
    end

    # deletes an image from the image pool.
    # +session+   string that represents user session
    # +id+        id of the image
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             otherwise it does not exist.
    def delete(session, id)
      @client.call_async('one.image.delete', session, id)
    end

    # enables or disables an image
    # +session+   string that represents user session
    # +id+        id of the image
    # +enabled+   true for enabling, false for disabling
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             otherwise it is the image id.
    def enable(session, id, enabled)
      @client.call_async('one.image.enable', session, id, enabled)
    end

    # publishes or unpublishes an image.
    # +session+   string that represents user session
    # +id+        id of the image
    # +published+ true for publishing, false for unpublishing
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             otherwise it is the image id.
    def publish(session, id, published)
      @client.call_async('one.image.publish', session, id, published)
    end
  end
end

# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
