require 'OpenNebula'

module RenkeiVPE
  class Site < PoolElement
    # Creates a Site description with just its identifier.
    # This method should be used to create plain Site objects.
    # +id+ the id of the user
    #
    def Site.build_xml(id=nil)
      if id
        user_xml = "<SITE><ID>#{id}</ID></SITE>"
      else
        user_xml = "<SITE></SITE>"
      end

      XMLElement.build_xml(user_xml, 'SITE')
    end

    def initialize(xml, client)
      super(xml, client)
      @client = client
    end

    # Allocate a new Site in RenkeiVPE
    #
    # +sitename+ A string containing the name of the Site.
    def allocate(sitename)
      rc = onecluster.allocate(sitename)
      if is_one_error?(rc)
        return Error.new(rc.message)
      end
    end

  private
    # TODO move to renkei_vpe.rb
    def is_one_error?(result)
      OpenNebula.is_error?(result)
    end

    # TODO move to renkei_vpe.rb
    def is_one_successful?(result)
      !OpenNebula.is_error?(result)
    end

    def oncluster(id=nil)
      return OpenNebula::Cluster.new(OpenNebula::Cluster.build_xml(id), @client)
    end

    def info(id)
      cluster =
        OpenNebula::Cluster.new(OpenNebula::Cluster.build_xml(id), @client)
      rc = cluster.info
      if OpenNebula.is_error?(rc)
        $stderr.puts 'Internal Error'
        return # TODO return error code
      end

      return nil
    end

  end
end

# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
