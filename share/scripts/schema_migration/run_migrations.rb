#! /bin/env ruby

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
