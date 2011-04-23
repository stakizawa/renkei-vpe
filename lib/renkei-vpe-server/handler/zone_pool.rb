require 'renkei-vpe-server/handler/base'
require 'rexml/document'

module RenkeiVPE
  module Handler

    class ZonePool < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.zonepool') do
        meth('val info(string)',
             'Retrieve information about zone pool',
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
        task('rvpe.zonepool.info', session) do
          doc = REXML::Document.new
          pool_e = REXML::Element.new('ZONE_POOL')
          doc.add(pool_e)

          RenkeiVPE::Model::Zone.each do |z|
            zone_e = Zone.to_xml_element(z, session)
            pool_e.add(zone_e)
          end

          return [true, doc.to_s]
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
