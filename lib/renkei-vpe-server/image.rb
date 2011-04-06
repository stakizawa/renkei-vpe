require 'renkei-vpe-server/server_role'

module RenkeiVPE
  class Image < ServerRole
    ##########################################################################
    # Define xml rpc interfaces
    ##########################################################################
    INTERFACE = XMLRPC::interface('rvpe.image') do
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


    ##########################################################################
    # Implement xml rpc functions
    ##########################################################################

    # return information about this image.
    # +session+   string that represents user session
    # +id+        id of the image
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the string with the information
    #             about the image
    def info(session, id)
      authenticate(session) do
        rc = call_one_xmlrpc('one.image.info', session, id)
        log_result('rvpe.image.info', rc)
        return rc
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
      authenticate(session) do
        rc = call_one_xmlrpc('one.image.allocate', session, template)
        log_result('rvpe.image.allocate', rc)
        return rc
      end
    end

    # deletes an image from the image pool.
    # +session+   string that represents user session
    # +id+        id of the image
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             otherwise it does not exist.
    def delete(session, id)
      authenticate(session) do
        rc = call_one_xmlrpc('one.image.delete', session, id)
        log_result('rvpe.image.delete', rc)
        return rc
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
      authenticate(session) do
        rc = call_one_xmlrpc('one.image.enable', session, id, enabled)
        log_result('rvpe.image.enable', rc)
        return rc
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
      authenticate(session) do
        rc = call_one_xmlrpc('one.image.publish', session, id, published)
        log_result('rvpe.image.publish', rc)
        return rc
      end
    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
