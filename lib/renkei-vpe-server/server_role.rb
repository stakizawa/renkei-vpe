require 'renkei-vpe-server/model'
require 'renkei-vpe-server/logger'
require 'renkei-vpe-server/one_client'
require 'thread'

module RenkeiVPE

  # All classes that process client request must have this class as their
  # super class.
  class ServerRole  # TODO rename to Hander
    include RenkeiVPE::OpenNebulaClient

    def initialize
      @lock = Mutex.new
      @log = RenkeiVPE::Logger.get_logger
    end

    def task(task_name, session, admin_auth=false, &block)
      @lock.synchronize do
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
    end

    def authenticate(session, admin_auth=false, &block)
      # 1. get user name
      username = get_user_from_session(session)

      # 2. check if user is registered in Renkei VPE
      u = RenkeiVPE::Model::User.find_by_name(username)[0]
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
