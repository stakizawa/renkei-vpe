require 'xmlrpc/client'

module RenkeiVPEServer
  class ImagePool
    def initialize(one_endpoint)
      @client = XMLRPC::Client.new2(one_endpoint)
    end

    # return information about image pool.
    # +session+   string that represents user session
    # +flag+      flag for condition
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the information string
    def info(session, flag)
      @client.call_async('one.imagepool.info', session, flag)
    end
  end
end

# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
