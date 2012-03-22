#! /bin/env ruby

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
    system("sqlite3 #{dbfile} 'ALTER TABLE virtual_machines ADD info TEXT;' 2>/dev/null")
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
