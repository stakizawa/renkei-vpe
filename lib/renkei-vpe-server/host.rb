require 'renkei-vpe-server/server_role'

module RenkeiVPE
  class Host < ServerRole
    ##########################################################################
    # Define xml rpc interfaces
    ##########################################################################
    INTERFACE = XMLRPC::interface('rvpe.host') do
      meth('val info(string, int)',
           'Retrieve information about the host',
           'info')
      meth('val enable(string, int, bool)',
           'Enables or disables a host',
           'enable')
    end


    ##########################################################################
    # Implement xml rpc functions
    ##########################################################################

    # return information about this host.
    # +session+   string that represents user session
    # +id+        id of the host
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the string with the information
    #             about the host
    def info(session, id)
      task('rvpe.host.info', session) do
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
      task('rvpe.host.enable', session, true) do
        call_one_xmlrpc('one.host.enable', session, id, enabled)
      end
    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
