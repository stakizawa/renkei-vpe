#
# Copyright 2011-2012 Shinichiro Takizawa
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


require 'renkei-vpe-server/model'
require 'renkei-vpe-server/logger'
require 'renkei-vpe-server/one_client'
require 'renkei-vpe-server/read_write_lock'

module RenkeiVPE
  ############################################################################
  # A module whose classes defines handlers for xmlrpc server
  ############################################################################
  module Handler

    # All classes that process client request must have this class as their
    # super class.
    class BaseHandler
      include RenkeiVPE::Const
      include RenkeiVPE::OpenNebulaClient
      include RenkeiVPE::Model

      def initialize
        @lock = ReadWriteLock.new
        @log = RenkeiVPE::Logger.get_logger
      end

      # It defines a task that update status of resources.
      def write_task(task_name, session, admin_auth=false, &block)
        task(task_name, session, :wt, admin_auth, &block)
      end

      # It defines a task that queries information about resources.
      def read_task(task_name, session, admin_auth=false, &block)
        task(task_name, session, :rd, admin_auth, &block)
      end

      # It is used for define an xml handler's task.
      # It does 1) locking, 2) authenticating, 3) executing a task, and
      # 4)returning a result to a client.
      # +task_name+   name of task
      # +session+     a string that represents a user session
      # +lock_mode+   a mode flag for exclusive access
      #               :rd for read lock and :wt for write lock.
      # +admin_auth+  it does authentication for the administrator if true,
      #               otherwise does authentication for usual users.
      # +block+       a block that defines a task routine
      # +return+      an array of [bool, result]. +bool+ is true if execution
      #               of the task is successful, otherwise false. +result+
      #               is defined by tasks. It can take integer, boolean,
      #               string, etc.
      def task(task_name, session, lock_mode, admin_auth=false, &block)
        begin
          # lock
          if lock_mode == :wt
            @lock.write_lock
          else
            @lock.read_lock
          end

          begin
            rc = authenticate(session, admin_auth, &block)
            log_msg = rc
          rescue => e
            rc = [false, e.message]
            log_msg = [false, e]
          end

        ensure
          # unlock
          if lock_mode == :wt
            @lock.write_unlock
          else
            @lock.read_unlock
          end
        end

        log_result(task_name, get_user_from_session(session), log_msg)
        return rc
      end

      def authenticate(session, admin_auth=false, &block)
        # 1. get user name
        username = get_user_from_session(session)

        # 2. check if user is registered in Renkei VPE
        u = RenkeiVPE::Model::User.find_by_name(username).last
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

      def admin_session(session, will_raise=true, msg=nil)
        rc = __authenticate(session)
        if rc[0] != 0
          msg ||= 'The operation requires the admin privilege.'
          @log.warn msg
          raise msg if will_raise
          return
        end

        yield
      end

      # It log rpc call result.
      # +task_name+  name of called method
      # +user+       name of user who executes this rpc call
      # +result[0]+  true or false
      # +result[1]+  a string representing error if result[0] is false,
      #              otherwise undefined
      def log_result(task_name, user, result)
        if result[0]
          log_success(user, task_name)
        else
          log_fail(user, task_name, result[1])
        end
      end

      def log_success(user, task_name)
        @log.info "User[#{user}] successfully executes TASK[#{task_name}]."
      end

      def log_fail(user, task_name, msg)
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
        @log.error "User[#{user}] failes to execute TASK[#{task_name}].\n" + newmsg
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
