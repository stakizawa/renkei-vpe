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
    on_shutdown do
      FileUtils.rm_rf($lock_dir)
    end
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
# CentOS5.x VM Finalizer (do nothing)
##############################################
class CentOS5 < Finalizer; end


##############################################
# CentOS6.x VM Finalizer
##############################################
class CentOS6 < Finalizer
  def final
    on_shutdown do
      FileUtils.rm_rf($lock_dir)

      # delete network configuration files only on shutdown
      FileUtils.rm('/etc/udev/rules.d/70-persistent-net.rules')
      Dir::glob('/etc/sysconfig/network-scripts/ifcfg-eth*') do |f|
        FileUtils.rm(f)
      end
    end
  end
end


###########################################
# main
###########################################
centos_file = '/etc/redhat-release'
if FileTest.exist?(centos_file)
  centos_ver = $1 if /^.+(\d+)\.\d+.*$/ =~ `cat #{centos_file}`
  if centos_ver == '5'
    CentOS5.new.final
  elsif centos_ver == '6'
    CentOS6.new.final
  else
    $stderr.puts "Not supported Linux"
  end
else
  $stderr.puts "Not supported Linux"
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
