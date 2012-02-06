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

# TODO not to use a separated file
psst_file = '/mnt/persistent'
unless FileTest.exist?(psst_file)
  $stderr.puts "File does not exist: #{psst_file}"
  $stderr.puts 'I assume that VM is a non-persistent VM.'
  $persistent = false
else
  File.open(psst_file) do |f|
    val = f.gets.strip.to_i
    $persistent = (val == 1)? true : false
  end
end


###########################################
# super class of VM initializers
###########################################
class Initializer
  def init
    set_hostname
    set_nics
    set_hostsfile
    set_dns
    set_ntp
    set_ssh_hostkey
    set_root_sshkey
    set_root_password_nil unless $DEBUG_MODE
  end

  protected

  def set_hostname
    raise NotImplementedError
  end

  def set_nics
    raise NotImplementedError
  end

  def set_hostsfile
    raise NotImplementedError
  end

  def set_dns
    raise NotImplementedError
  end

  def set_ntp
    raise NotImplementedError
  end

  def set_ssh_hostkey
    raise NotImplementedError
  end

  def set_root_sshkey
    raise NotImplementedError
  end

  def set_root_password_nil
    raise NotImplementedError
  end

  #########################################
  # utility functions
  #########################################

  # lock files not to update existing ones
  def lock(name)
    lock_file = $lock_dir + '/' + name
    unless FileTest.exist?(lock_file)
      FileUtils.touch(lock_file)
      yield
    end
  end

  # do some process when nonpersistent image
  def nonpersistent
    yield if !$persistent
  end
end


##############################################
# VM initializer for CentOS 5.x compatible OS
##############################################
class CentOS5 < Initializer
  def set_hostname
    lock('hostname') do
      nonpersistent do
        hostname = $cnt_hash['HOSTNAME']
        system("hostname #{hostname}")
        host_conf = '/etc/sysconfig/network'
        FileUtils.mv(host_conf, host_conf + '.orig')
        File.open(host_conf, 'w') do |f|
          File.open(host_conf + '.orig') do |inf|
            inf.each_line do |line|
              if /^HOSTNAME=/ =~ line
                f.puts "HOSTNAME=#{hostname}"
              else
                f.puts line
              end
            end
          end
        end
        FileUtils.rm(host_conf + '.orig') unless $DEBUG_MODE
      end
    end
  end

  def set_nics
    # find interface parameters
    ifs = Hash.new
    $cnt_hash.each_key do |k|
      if /^(eth\d+)_(.+)/i =~ k
        if ifs[$1].nil?
          ifs[$1] = Hash.new
        end
        h = ifs[$1]
        h[$2] = $cnt_hash[k]
      end
    end

    # write interface definitions
    ifs.each_key do |k|
      if_name = k.downcase
      lock(if_name) do
        if_prms = ifs[k]
        file = "/etc/sysconfig/network-scripts/ifcfg-#{if_name}"
        File.open(file, 'w') do |f|
          f.puts <<EOS
DEVICE=#{if_name}
BOOTPROTO=none
ONBOOT=yes
HWADDR=#{if_prms['HWADDR']}
NETMASK=#{if_prms['NETMASK']}
IPADDR=#{if_prms['IPADDR']}
TYPE=Ethernet
EOS
          f.puts "GATEWAY=#{if_prms['GATEWAY']}" if if_prms['GATEWAY']
          f.puts "NETWORK=#{if_prms['NETWORK']}" if if_prms['NETWORK']
        end
      end
    end
  end

  def set_hostsfile
    lock('hosts_file') do
      nonpersistent do
        File.open('/etc/hosts', 'w') do |f|
          f.puts <<EOS
# Do not remove the following line, or various programs
# that require network functionality will fail.
127.0.0.1       localhost.localdomain localhost
::1             localhost6.localdomain6 localhost6

EOS
          short_name = $cnt_hash['HOSTNAME'].split('.')[0]
          ipaddr = ($cnt_hash['PRIMARY_IPADDR'])? $cnt_hash['PRIMARY_IPADDR'] : $cnt_hash['ETH0_IPADDR']
          f.puts ipaddr + "\t" + $cnt_hash['HOSTNAME'] + "\t" + short_name
        end
      end
    end
  end

  def set_dns
    if $cnt_hash['NAMESERVERS']
      lock('resolver') do
        nonpersistent do
          # format of NAMESERVERS is '192.168.0.1 192.168.0.2'
          File.open('/etc/resolv.conf', 'w') do |f|
            $cnt_hash['NAMESERVERS'].split.each do |n|
              f.puts "nameserver #{n}"
            end
          end
        end
      end
    end
  end

  def set_ntp
    if $cnt_hash['NTPSERVERS']
      lock('ntpd') do
        nonpersistent do
          # format of NTPSERVERS is 'ntp.nict.jp 192.168.0.1'
          servers = $cnt_hash['NTPSERVERS'].split
          ntp_conf = '/etc/ntp.conf'
          FileUtils.mv(ntp_conf, ntp_conf + '.orig')
          File.open(ntp_conf, 'w') do |f|
            File.open(ntp_conf + '.orig') do |inf|
              inf.each_line do |line|
                unless /^server\s+(.+)/ =~ line
                  f.puts line
                else
                  if /^127\.127\.1\.0/ =~ $1
                    f.puts line
                  else
                    f.puts "server #{servers.shift}" if servers.size > 0
                  end
                end
              end
            end
          end
          FileUtils.rm(ntp_conf + '.orig') unless $DEBUG_MODE
        end
      end
    end
  end

  def set_ssh_hostkey
    lock('ssh_host_keys') do
      nonpersistent do
        # delete existing files
        ssh_dir = '/etc/ssh'
        files = [ 'ssh_host_key', 'ssh_host_rsa_key', 'ssh_host_dsa_key' ]
        files.each do |file|
          key_file = ssh_dir + '/' + file
          FileUtils.rm_rf(key_file)
          FileUtils.rm_rf(key_file + '.pub')
        end
      end
      # if no ssh host keys, sshd will generate them when it starts
    end
  end

  def set_root_sshkey
    if FileTest.exist?("/mnt/#{$cnt_hash['ROOT_PUBKEY']}")
      lock('root_sshpubkey') do
        nonpersistent do
          FileUtils.mkdir_p('/root/.ssh')
          FileUtils.cp("/mnt/#{$cnt_hash['ROOT_PUBKEY']}", '/root/.ssh/authorized_keys')
          FileUtils.chmod_R(0600, '/root/.ssh')
        end
      end
    end
  end

  def set_root_password_nil
    lock('root_pass') do
      nonpersistent do
        files = [ '/etc/shadow', '/etc/shadow-' ]
        files.each do |file|
          orig = file + '.orig'
          FileUtils.cp(file, orig)
          File.open(file, 'w') do |f|
            File.open(orig) do |inf|
              inf.each_line do |line|
                if /^root/ =~ line
                  r_args = line.chomp.split(':')
                  r_args[1] = '*'
                  f.puts r_args.join(':') + ':::'
                else
                  f.puts line
                end
              end
            end
          end
          FileUtils.rm_f(orig) unless $DEBUG_MODE
        end
      end
    end
  end

end


##############################################
# VM initializer for CentOS 6.x compatible OS
##############################################
class CentOS6 < CentOS5; end


###########################################
# main
###########################################
centos_file = '/etc/redhat-release'
if FileTest.exist?(centos_file)
  centos_ver = $1 if /^.+(\d+)\.\d+.*$/ =~ `cat #{centos_file}`
  if centos_ver == '5'
    CentOS5.new.init
  elsif centos_ver == '6'
    CentOS6.new.init
  else
    $stderr.puts "Not supported Linux"
  end
else
  $stderr.puts "Not supported Linux"
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
