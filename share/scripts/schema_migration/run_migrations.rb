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


if ARGV.size != 1
  puts 'specify db file name (path of rvped.db).'
  exit 1
end
dbfile = File.expand_path(ARGV[0])

# find migrations
dir_name = File.dirname(File.expand_path(__FILE__))
mgrt_files = []
Dir.foreach(dir_name) do |file|
  if /update_\d+/ =~ file
    mgrt_files << file
  end
end
mgrt_files.sort!

mgrt_files.each do |file|
  system("#{dir_name}/#{file} #{dbfile}")
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
