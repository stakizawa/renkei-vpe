require 'renkei-vpe-server/logger'
require 'xmlrpc/client'

module RenkeiVPE

  # All classes which access OpenNebula must include this module.
  module OpenNebulaClient
    ONE_AUTH_METHOD = 'one.userpool.info'

    def init(one_endpoint)
      @@client = XMLRPC::Client.new2(one_endpoint)
      @@log = RenkeiVPE::Logger.get_logger
    end
    module_function :init

    protected

    def one_auth(session, admin_auth=false, &block)
      result = __authenticate(session)
      if result[0] == 0
        result = [true,  result[1]]
      elsif result[0] == 1
        @@log.warn result[1]
        result = [false, result[1]]
      else # result[0] == 2
        if admin_auth
          @@log.warn result[1]
          result = [false, result[1]]
        else
          result = [true,  result[1]]
        end
      end

      if block_given?
        return result unless result[0]
        yield block
      else
        return result
      end
    end

    def get_user_from_session(session)
      return session.split(':')[0]
    end

    def call_one_xmlrpc_nolog(method, session, *args)
      unless @@client
        msg = 'RenkeiVPE::OpenNebulaClient.init is not called!'
        @@log.fatal msg
        raise msg
      end
      @@client.call_async(method, session, *args)
    end

    def call_one_xmlrpc(method, session, *args)
      rc = call_one_xmlrpc_nolog(method, session, *args)
      if rc[0]
        @@log.debug("'#{method}' is successfully executed.")
      else
        @@log.error("'#{method}' is failed.\n#{rc[1]}")
      end
      return rc
    end

    module_function :call_one_xmlrpc, :call_one_xmlrpc_nolog

    private

    # It authenticate user session.
    # +session+    string that represents user session
    # +return[0]+  0 if user is the administrator.
    #              1 if authentication failed.
    #              2 if user is not the administrator.
    # +return[1]+  string that represents message
    def __authenticate(session)
      result = call_one_xmlrpc_nolog(ONE_AUTH_METHOD, session)
      user = session.split(':')[0]
      if result[0]
        val = 0
        msg = "Authentication succeeded: #{user}"
      else
        if /perform INFO on USER Pool$/ =~ result[1].strip
          val = 2
          msg = "Not the administrator: #{user}"
        else
          val = 1
          msg = "Authentication failed: #{user}"
        end
      end
      return [val, msg]
    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
