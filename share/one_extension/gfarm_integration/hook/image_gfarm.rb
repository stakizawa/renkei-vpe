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


ONE_LOCATION=ENV["ONE_LOCATION"]

if !ONE_LOCATION
    RUBY_LIB_LOCATION="/usr/lib/one/ruby"
else
    RUBY_LIB_LOCATION=ONE_LOCATION+"/lib/ruby"
end

$: << RUBY_LIB_LOCATION

GFMV = '/usr/bin/gfmv'

GFARM_MOUNT_POINT = ONE_LOCATION + '/var/images'
GFARM_DIR         = '/work/one_images'
GFARM_TEMP_DIR    = GFARM_DIR + '/temporal'

require 'fileutils'
require 'OpenNebula'
include OpenNebula

if !(vm_id=ARGV[0])
    exit -1
end


begin
    client = Client.new()
rescue Exception => e
    puts "Error: #{e}"
    exit(-1)
end

img_repo = ImageRepository.new

vm = VirtualMachine.new(
                VirtualMachine.build_xml(vm_id),
                client)
vm.info

vm.each('TEMPLATE/DISK') do |disk|
    disk_id     = disk["DISK_ID"]
    source_path = GFARM_TEMP_DIR + "/#{vm_id}_disk.#{disk_id}"

    if image_id = disk["SAVE_AS"]
        image=Image.new(
                Image.build_xml(image_id),
                client)
        result = image.info
        if !OpenNebula.is_error?(result)
            dest_path = image['SOURCE'].gsub(/\/\/+/, '/')
            dest_gf_path = dest_path.gsub(GFARM_MOUNT_POINT, GFARM_DIR)
            system("#{GFMV} #{source_path} #{dest_gf_path}")
            system("/bin/chmod 0660 #{dest_path}")
            image.enable
        else
            exit -1
        end
    end
end
