require 'renkei-vpe-server/server_role'
require 'rexml/document'

module RenkeiVPE
  class VMTypePool < ServerRole
    ##########################################################################
    # Define xml rpc interfaces
    ##########################################################################
    INTERFACE = XMLRPC::interface('rvpe.vmtypepool') do
      meth('val info(string)',
           'Retrieve information about vm type pool',
           'info')
    end


    ##########################################################################
    # Implement xml rpc functions
    ##########################################################################

    # return information about vm type pool.
    # +session+   string that represents user session
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the information string
    def info(session)
      authenticate(session) do
        begin
          pool_e = REXML::Element.new('VMTYPE_POOL')
          RenkeiVPE::Model::VMType.each do |type|
            type_e = VMType.to_xml_element(type)
            pool_e.add(type_e)
          end
          doc = REXML::Document.new
          doc.add(pool_e)
          rc = [true, doc.to_s]
        rescue => e
          rc = [false, e.message]
        end

        log_result('rvpe.vmtypepool.info', rc)
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
