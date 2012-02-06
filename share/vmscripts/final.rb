#! /usr/bin/env ruby
require 'fileutils'

# if true, this script remains some original config files and
# doesn't delete root password
$DEBUG_MODE = true

###########################################
# check parameters
###########################################
if ARGV.size != 2
  $stderr.puts 'Two parameters are required.'
  $stderr.puts "#{File.basename(__FILE__)} context_file lock_dir"
  exit 1
end

context = ARGV.shift # '/mnt/context.sh'
unless FileTest.exist?(context)
  $stderr.puts "File does not exist: #{context}"
  exit 1
end
# read the context
$cnt_hash = Hash.new
if FileTest.exist?(context)
  File.open(context) do |f|
    f.each_line do |line|
      next if /^#/ =~ line
      key,val = line.chomp.split('=', 2)
      $cnt_hash[key] = val.sub(/^"(.+)"$/, '\1')
    end
  end
end

$lock_dir = ARGV.shift # '/var/lib/rvpe_init'
FileUtils.mkdir_p($lock_dir) unless FileTest.exist?($lock_dir)


###########################################
# super class of VM finalizer
###########################################
class Finalizer
  def final
    # by default, do nothing
  end

  protected

  #########################################
  # utility functions
  #########################################

  # do some process on shutdown
  def on_shutdown
    next_runlevel = `/sbin/runlevel`.split[1].strip
    yield if next_runlevel == '0'
  end

  # do some process on reboot
  def on_reboot
    next_runlevel = `/sbin/runlevel`.split[1].strip
    yield if next_runlevel == '6'
  end
end


##############################################
# Default VM Finalizer (do nothing)
##############################################
class CentOS5 < Finalizer
end


###########################################
# main
###########################################
centos_file = '/etc/redhat-release'
if FileTest.exist?(centos_file)
  centos_ver = $1 if /^.+(\d+)\.\d+.*$/ =~ `cat #{centos_file}`
  if centos_ver == '5'
    CentOS5.new.final
  else
    $stderr.puts "currently not supported"
  end
else
  $stderr.puts "currently not supported"
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
