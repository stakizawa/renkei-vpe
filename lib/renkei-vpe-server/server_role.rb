require 'renkei-vpe-server/model'
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

  # All classes that process client request must have this class as their
  # super class.
  class ServerRole
    include RenkeiVPE::OpenNebulaClient

    def initialize
      @log = RenkeiVPE::Logger.get_logger
    end

    def task(task_name, session, admin_auth=false, &block)
      begin
        rc = authenticate(session, admin_auth, &block)
        log_msg = rc
      rescue => e
        rc = [false, e.message]
        log_msg = [false, e]
      end
      log_result(task_name, log_msg)
      return rc
    end

    def authenticate(session, admin_auth=false, &block)
      # 1. get user name
      username = get_user_from_session(session)

      # 2. check if user is registered in Renkei VPE
      u = RenkeiVPE::Model::User.find_by_name(username)
      unless u
        msg = "User is not found: #{username}"
        @log.warn msg
        return [false, msg]
      end

      # 3. check if user is enabled
      unless u.enabled == 1
        msg = "User is not enabled: #{username}"
        @log.warn msg
        return [false, msg]
      end

      # 4. do one authentication
      one_auth(session, admin_auth, &block)
    end

    def admin_session(session, will_raise=true)
      rc = __authenticate(session)
      if rc[0] != 0
        msg = 'The operation requires the admin privilege.'
        @log.warn msg
        raise msg if will_raise
        return
      end

      yield
    end

    # It log rpc call result.
    # +task_name+  name of called method
    # +result[0]+  true or false
    # +result[1]+  a string representing error if result[0] is false,
    #              otherwise undefined
    def log_result(task_name, result)
      if result[0]
        log_success(task_name)
      else
        log_fail(task_name, result[1])
      end
    end

    def log_success(task_name)
      @log.info "'#{task_name}' is successfully executed."
    end

    def log_fail(task_name, msg)
      newmsg = ''
      case msg
      when ::String
        newmsg = msg
      when ::Exception
        newmsg = "#{ msg.message } (#{ msg.class })\n" <<
          (msg.backtrace || []).join("\n")
      else
        newmsg = msg.inspect
      end
      @log.error "'#{task_name}' is failed.\n" + newmsg
    end

  end

end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
