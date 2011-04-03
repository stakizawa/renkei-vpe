require 'xmlrpc/client'

module RenkeiVPE

  # All classes which access OpenNebula must include this module.
  module OpenNebulaClient
    ONE_AUTH_METHOD = 'one.userpool.info'

    def init(one_endpoint)
      @@client = XMLRPC::Client.new2(one_endpoint)
    end
    module_function :init

    protected

    def one_auth(session, strict_auth=false, &block)
      result = __authenticate(session)
      if result[0] == 0
        result = [true,  result[1]]
      elsif result[0] == 1
        result = [false, result[1]]
      else # result[0] == 2
        result = [false, result[1]] if strict_auth
        result = [true,  result[1]]
      end

      if block_given?
        return result unless result[0]
        yield block
      else
        return result
      end
    end

    def call_one_xmlrpc(method, session, *args)
      raise 'RenkeiVPE::OpenNebulaClient.init is not called!' unless @@client
      @@client.call_async(method, session, *args)
    end

    private

    # It authenticate user session.
    # +session+    string that represents user session
    # +return[0]+  0 if authentication succeeded.
    #              1 if authentication failed.
    #              2 if user is not the administrator
    # +return[1]+  string that represents message
    def __authenticate(session)
      result = call_one_xmlrpc(ONE_AUTH_METHOD, session)
      user = 'User[' + session.split(':')[0] + ']'
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
    include RenkeiVPE::Database
    include RenkeiVPE::OpenNebulaClient

    def authenticate(session, strict_auth=false, &block)
      # 1. get user name
      # it assumes that session string equals to one session string
      username = session.split(':')[0]

      # 2. check if user is registered in Renkei VPE
      rc = Users.find('id', "name='#{username}'")
      return [false, "User named '#{username}' is not found."] unless rc
      userid = rc[0]

      # 3. check if user is enabled
      rc = Users.find('enabled', "id='#{userid}'")
      unless rc[0] == '1'
        return [false, "User named '#{username}' is not enabled."]
      end

      # 4. do one authentication
      one_auth(session, strict_auth, &block)
    end
  end

end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
