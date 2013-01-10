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


require 'pp'
require 'rubygems'
require 'sqlite3'
require 'tempfile'


mgrt_name = File.basename(__FILE__).split('.')[0]

if ARGV.size != 1
  puts 'specify db file name (path of rvped.db).'
  exit 1
end
dbfile = File.expand_path(ARGV[0])

# check if the db file needs a migrate
vmdb_schema = `sqlite3 #{dbfile} '.schema vm_types' 2>/dev/null`
found = false
vmdb_schema.each_line do |line|
  if /^\s*name\s+VARCHAR\(256\) UNIQUE,\s*$/ =~ line
    found |= true
  end
  if /\s*weight\s+TEXT\s*/ =~ line
    found |= true
  end
end

unless found
  puts "[#{mgrt_name}]  Run migration."
  puts "    This migration will do the following schema modification."
  puts "    - make 'name' field UNIQUE"
  puts "    - add 'weight' field to 'vm_types' table whose data type is"
  puts "      INTEGER"
  puts "    - set 'weight' fields of all VM types as 1"
  puts
  print "    Is this OK to apply? [Y/n]:"
  str = STDIN.gets
  if str[0] == ?y || str[0] == ?Y ||str[0] == ?\n
    # apply migration
    # 1. make 'name' field UNIQUE
    sql_file = nil
    Tempfile.open(mgrt_name) do |f|
      sql_file = f.path
      dump_sql = `sqlite3 #{dbfile} '.dump vm_types' 2>/dev/null`
      dump_sql.each_line do |l|
        if /^\s+name\s+VARCHAR.+$/ =~ l
          l = "  name        VARCHAR(256) UNIQUE,\n"
        end
        f.puts l
      end
    end
    begin
      db = SQLite3::Database.new(dbfile)
      db.execute('DROP TABLE vm_types')
    ensure
      db.close
    end
    system("sqlite3 #{dbfile} '.read #{sql_file}' 2>/dev/null")

    # 2. add 'weight' field
    begin
      db = SQLite3::Database.new(dbfile)
      db.execute('ALTER TABLE vm_types ADD weight INTEGER')
    ensure
      db.close
    end

    # 3. set initial values to 'weight' field
    begin
      db = SQLite3::Database.new(dbfile)
      db.execute('UPDATE vm_types SET weight=1')
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
