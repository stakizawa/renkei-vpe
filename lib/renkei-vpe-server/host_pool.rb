require 'renkei-vpe-server/server_role'

module RenkeiVPE
  class HostPool < ServerRole
    ##########################################################################
    # Define xml rpc interfaces
    ##########################################################################
    INTERFACE = XMLRPC::interface('rvpe.hostpool') do
      meth('val info(string)',
           'Retrieve information about host pool',
           'info')
    end


    ##########################################################################
    # Implement xml rpc functions
    ##########################################################################

    # return information about host pool.
    # +session+   string that represents user session
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the information string
    def info(session)
      task('rvpe.hostpool.info', session) do
        call_one_xmlrpc('one.hostpool.info', session)
      end
    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
