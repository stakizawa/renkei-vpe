#! /bin/env ruby
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


module RenkeiVPETool
  module CliUtilities

    def exit_on_parse_error(errmsg=nil)
      $stderr.puts errmsg if errmsg
      $stderr.puts
      $stderr.puts "Run '#{CMD_NAME} help' to see the usage."
      exit 1
    end

    def check_command(name, number)
      if ARGV.length < number
        print "Command #{name} requires "
        if number > 1
          puts "#{number} parameters to run."
        else
          puts "one parameter to run"
        end
        exit 1
      end
    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
