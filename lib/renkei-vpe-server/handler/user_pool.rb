require 'renkei-vpe-server/handler/base'
require 'rexml/document'

module RenkeiVPE
  module Handler

    class UserPool < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.userpool') do
        meth('val info(string)',
             'Retrieve information about user pool',
             'info')
      end


      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # return information about user pool.
      # +session+   string that represents user session
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the information string
      def info(session)
        task('rvpe.userpool.info', session, true) do
          rc = call_one_xmlrpc('one.userpool.info', session)
          raise rc[1] unless rc[0]

          doc = REXML::Document.new(rc[1])
          doc.each_element('/USER_POOL/USER') do |e|
            User.modify_onexml(e)
          end

          [true, doc.to_s]
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
