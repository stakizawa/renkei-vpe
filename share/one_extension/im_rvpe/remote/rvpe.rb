#!/usr/bin/env ruby
#
# Copyright 2011-2013 Shinichiro Takizawa
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

def print_info(name, value)
  value = "0" if value.nil? or value.to_s.strip.empty?
  puts "#{name}=#{value}"
end


nodeinfo_text = `virsh -c qemu:///system nodeinfo`
exit(-1) if $? != 0
nodeinfo_text.split(/\n/).each do |each|
  if each.match('^CPU\(s\)')
    $total_cpu    = each.split(":")[1].strip.to_i * 100
  elsif each.match('^CPU frequency')
    $cpu_speed    = each.split(":")[1].strip.split(" ")[0]
  elsif each.match('^Memory size')
    $total_memory = each.split(":")[1].strip.split(" ")[0].to_i
  end
end

nodelist_text = `virsh -c qemu:///system list`
exit(-1) if $? != 0
nodelist = []
nodelist_text.split(/\n/).each do |each|
  if each.match('^\s*(\d+)')
    nodelist << $1
  end
end

$used_cpu = 0
nodelist.each do |each|
  vcpuinfo_text = `virsh -c qemu:///system vcpuinfo #{each}`
  vcpuinfo_text.split(/\n/).each do |each|
    $used_cpu += 100 if each.match('^\s*VCPU')
  end
end
$free_cpu = $total_cpu - $used_cpu

$used_memory = 0
nodelist.each do |each|
  dommemstat_text = `virsh -c qemu:///system dommemstat #{each}`
  dommemstat_text.split(/\n/).each do |each|
    if each.match('^\s*actual')
      $used_memory += each.split(/\s+/)[1].to_i
    end
  end
end
$free_memory = $total_memory - $used_memory


print_info("HYPERVISOR","kvm")

print_info("TOTALCPU",$total_cpu)
print_info("CPUSPEED",$cpu_speed)

print_info("TOTALMEMORY",$total_memory)
print_info("USEDMEMORY",$used_memory)
print_info("FREEMEMORY",$free_memory)

print_info("FREECPU",$free_cpu)
print_info("USEDCPU",$used_cpu)

print_info("NETRX",$netrx)
print_info("NETTX",$nettx)
