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


require 'rubygems'
require 'sqlite3'

mgrt_name = File.basename(__FILE__).split('.')[0]

if ARGV.size != 1
  puts 'specify db file name (path of rvped.db).'
  exit 1
end
dbfile = File.expand_path(ARGV[0])

# check if the db file needs a migrate
vmdb_schema = `sqlite3 #{dbfile} '.schema virtual_machines' 2>/dev/null`
found = false
vmdb_schema.each_line do |line|
  if /\s*info\s+TEXT\s*/ =~ line
    found = true
  end
end

unless found
  puts "[#{mgrt_name}]  Run migration."
  puts "    This will add 'info' field to 'virtual_machines' table whose"
  puts "    data type is TEXT."
  print "    Is this OK to apply? [Y/n]:"
  str = STDIN.gets
  if str[0] == ?y || str[0] == ?Y ||str[0] == ?\n
    # add 'info' field
    begin
      db = SQLite3::Database.new(dbfile)
      db.execute('ALTER TABLE virtual_machines ADD info TEXT')
    ensure
      db.close
    end
    puts "    Migration is done."
  else
    puts "    Migration is canceled."
  end
else
  puts "[#{mgrt_name}]  No need to run migration."
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
