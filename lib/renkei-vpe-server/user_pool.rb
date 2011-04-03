require 'renkei-vpe-server/server_role'
require 'rexml/document'

module RenkeiVPE
  class UserPool < ServerRole

    # return information about image pool.
    # +session+   string that represents user session
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the information string
    def info(session)
      authenticate(session, true) do
        rc = call_one_xmlrpc('one.userpool.info', session)
        return rc unless rc[0]

        doc = REXML::Document.new(rc[1])
        doc.each_element('/USER_POOL/USER') do |e|
          # TODO replace ID
          User.insert_zones_to_onexml(e)
        end

        return [true, doc.to_s]
      end
    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
