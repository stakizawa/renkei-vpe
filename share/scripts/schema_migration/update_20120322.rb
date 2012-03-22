#! /bin/env ruby
require 'pp'
require 'rubygems'
require 'sqlite3'


mgrt_name = File.basename(__FILE__).split('.')[0]

if ARGV.size != 1
  puts 'specify db file name (path of rvped.db).'
  exit 1
end
dbfile = File.expand_path(ARGV[0])

# check if the db file needs a migrate
vmdb_schema = `sqlite3 #{dbfile} '.schema users' 2>/dev/null`
found = false
vmdb_schema.each_line do |line|
  if /\s*limits\s+TEXT\s*/ =~ line
    found = true
  end
end

unless found
  puts "[#{mgrt_name}]  Run migration."
  puts "    This migration will do the following schema modification."
  puts "    - add 'limits' field to 'users' table whose data type is"
  puts "      TEXT"
  puts "    - set 'limits' field as users can run 1 VM in the enabled"
  puts "      zones"
  print "    Is this OK to apply? [Y/n]:"
  str = STDIN.gets
  if str[0] == ?y || str[0] == ?Y ||str[0] == ?\n
    system("sqlite3 #{dbfile} 'ALTER TABLE users ADD limits TEXT;' 2>/dev/null")

    begin
      db = SQLite3::Database.new(dbfile)
      rows = db.execute('select * from users')
    ensure
      db.close
    end
    rows.each do |user|
      zids = user[4].strip.split(';')
      if zids.size > 0
        lmts = []
        zids.size.times do |i|
          lmts << '1'
        end
        lmts_str = lmts.join(';')
        system("sqlite3 #{dbfile} 'UPDATE users SET limits=\"#{lmts_str}\" where id=#{user[0]};' 2>/dev/null")
      end
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
