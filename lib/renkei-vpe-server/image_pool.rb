require 'renkei-vpe-server/server_role'

module RenkeiVPE
  class ImagePool < ServerRole
    ##########################################################################
    # Define xml rpc interfaces
    ##########################################################################
    INTERFACE = XMLRPC::interface('rvpe.imagepool') do
      meth('val info(string, int)',
           'Retrieve information about image pool',
           'info')
    end


    ##########################################################################
    # Implement xml rpc functions
    ##########################################################################

    # return information about image pool.
    # +session+   string that represents user session
    # +flag+      flag for condition
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the information string
    def info(session, flag)
      task('rvpe.imagepool.info', session) do
        if flag <= -2 || flag >= 0
          admin_session(session) do; end
        else # flag == -1
        end

        call_one_xmlrpc('one.imagepool.info', session, flag)
      end
    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
