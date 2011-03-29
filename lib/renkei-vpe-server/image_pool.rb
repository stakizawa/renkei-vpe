require 'renkei-vpe-server/one_client'

module RenkeiVPE
  class ImagePool < OpenNebulaClient
    def initialize(one_endpoint)
      super(one_endpoint)
    end

    # return information about image pool.
    # +session+   string that represents user session
    # +flag+      flag for condition
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the information string
    def info(session, flag)
      one_auth(session) do
        call_one_xmlrpc('one.imagepool.info', session, flag)
      end
    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
