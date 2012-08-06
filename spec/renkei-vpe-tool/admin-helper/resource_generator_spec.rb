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


require 'spec_helper'
require 'renkei-vpe-tool/admin-helper/resource_generator'
require 'yaml'

module RenkeiVPETool
  module AdminHelper

    describe ResourceGenerator do
      let(:rgen) do
        ResourceGenerator.new
      end

      let(:input_zone_csv) do <<EOS
ZONE_NAME, tokyo_tech
DESCRIPTION, Tokyo Institute of Technology
SERVERS, hpci-vms00-in.r.gsic.titech.ac.jp, hpci-vms01-in.r.gsic.titech.ac.jp
EOS
      end
      let(:output_zone_hash) do
        {
          'name'        => 'tokyo_tech',
          'description' => 'Tokyo Institute of Technology',
          'host'        => [ 'hpci-vms00-in.r.gsic.titech.ac.jp',
                             'hpci-vms01-in.r.gsic.titech.ac.jp' ]
        }
      end

      let(:input_min_zone_csv) do <<EOS
ZONE_NAME, tokyo_tech
EOS
      end
      let(:output_min_zone_hash) do
        { 'name'        => 'tokyo_tech' }
      end

      let(:input_no_name_zone_csv) do <<EOS
DESCRIPTION, Tokyo Institute of Technology
SERVERS, hpci-vms00-in.r.gsic.titech.ac.jp, hpci-vms01-in.r.gsic.titech.ac.jp
EOS
      end

      let(:input_unkn_attr_zone_csv) do <<EOS
ZONE_NAME, tokyo_tech
DESCRIPTION, Tokyo Institute of Technology
SERVERS, hpci-vms00-in.r.gsic.titech.ac.jp, hpci-vms01-in.r.gsic.titech.ac.jp
OS_IMAGE,test
EOS
      end

      let(:input_vnet_csv) do <<EOS
NETWORK_NAME, csi-grid
DESCRIPTION, CSI-Grid VPN in Tokyo Institute of Technology
ZONE_NAME, tokyo_tech
ADDRESS, 210.146.72.0
NETMASK, 255.255.252.0
GATEWAY, 210.146.75.254
DNS_SERVERS, 210.146.74.243
NTP_SERVERS, 210.146.75.200, 210.146.75.201
BRIDGE, br5
VM_HOSTS
vm00.g.gsic.titech.ac.jp, 210.146.75.204
vm01.g.gsic.titech.ac.jp, 210.146.75.205
EOS
      end

      let(:output_vnet_hash) do
        {
          'name'        => 'csi-grid',
          'description' => 'CSI-Grid VPN in Tokyo Institute of Technology',
          'address'     => '210.146.72.0',
          'netmask'     => '255.255.252.0',
          'gateway'     => '210.146.75.254',
          'dns'         => [ '210.146.74.243' ],
          'ntp'         => [ '210.146.75.200', '210.146.75.201' ],
          'lease'       => [
                            { 'name' => 'vm00.g.gsic.titech.ac.jp',
                              'address' => '210.146.75.204' },
                            { 'name' => 'vm01.g.gsic.titech.ac.jp',
                              'address' => '210.146.75.205' }
                           ],
          'interface'   => 'br5'
        }
      end

      let(:input_no_name_vnet_csv) do <<EOS
DESCRIPTION, CSI-Grid VPN in Tokyo Institute of Technology
ZONE_NAME, tokyo_tech
ADDRESS, 210.146.72.0
NETMASK, 255.255.252.0
GATEWAY, 210.146.75.254
DNS_SERVERS, 210.146.74.243
NTP_SERVERS, 210.146.75.200, 210.146.75.201
BRIDGE, br5
VM_HOSTS
vm00.g.gsic.titech.ac.jp, 210.146.75.204
vm01.g.gsic.titech.ac.jp, 210.146.75.205
EOS
      end

      let(:input_unkn_attr_vnet_csv) do <<EOS
NETWORK_NAME, csi-grid
DESCRIPTION, CSI-Grid VPN in Tokyo Institute of Technology
ZONE_NAME, tokyo_tech
ADDRESS, 210.146.72.0
NETMASK, 255.255.252.0
GATEWAY, 210.146.75.254
DNS_SERVERS, 210.146.74.243
NTP_SERVERS, 210.146.75.200, 210.146.75.201
BRIDGE, br5
VM_TYPE, small
VM_HOSTS
vm00.g.gsic.titech.ac.jp, 210.146.75.204
vm01.g.gsic.titech.ac.jp, 210.146.75.205
EOS
      end


      context '#gen_zone' do
        it 'will generate a yaml doc with full csv file.' do
          yaml_doc = rgen.gen_zone(input_zone_csv)
          data = YAML.load(yaml_doc)
          data.should == output_zone_hash
        end

        it 'will generate a yaml doc with minimum csv file.' do
          yaml_doc = rgen.gen_zone(input_min_zone_csv)
          data = YAML.load(yaml_doc)
          data.should == output_min_zone_hash
        end

        it 'will raise with a csv file that does not include name.' do
          lambda do
            yaml_doc = rgen.gen_zone(input_no_name_zone_csv)
          end.should raise_error(RuntimeError,
                                 'ZONE_NAME attribute is required.')
        end

        it 'will raise with a csv file including unknown attribute.' do
          lambda do
            yaml_doc = rgen.gen_zone(input_unkn_attr_zone_csv)
          end.should raise_error(RuntimeError,
                                 'Unknown attribute: OS_IMAGE')
        end
      end

      context "#gen_vnet" do
        it 'will generate a yaml doc with full csv file.' do
          yaml_doc = rgen.gen_vnet(input_vnet_csv)
          data = YAML.load(yaml_doc)
          data.should == output_vnet_hash
        end

        it 'will raise with a csv file that lacks any important attribute.' do
          lambda do
            yaml_doc = rgen.gen_vnet(input_no_name_vnet_csv)
          end.should raise_error(RuntimeError,
                                 'NETWORK_NAME attribute is required.')
        end

        it 'will raise with a csv file including unknown attribute.' do
          lambda do
            yaml_doc = rgen.gen_vnet(input_unkn_attr_vnet_csv)
          end.should raise_error(RuntimeError,
                                 'Unknown attribute: VM_TYPE')
        end
      end

      context "#get_zone_with_vnet" do
        let(:output_zone_vnet_hash) do
          hash = output_zone_hash.dup
          hash['network'] = [ output_vnet_hash ]
          hash
        end

        let(:input_vnet_csv2) do <<EOS
NETWORK_NAME, internet
DESCRIPTION, The Internet segment in Tokyo Tech
ZONE_NAME, tokyo_tech
ADDRESS, 131.112.28.0
NETMASK, 255.255.253.0
GATEWAY, 131.112.28.254
DNS_SERVERS, 131.112.125.58
NTP_SERVERS, ntp1.noc.titech.ac.jp
BRIDGE, br0
VM_HOSTS
vm00.m.gsic.titech.ac.jp, 131.112.28.100
EOS
        end

        let(:output_vnet_hash2) do
          {
            'name'        => 'internet',
            'description' => 'The Internet segment in Tokyo Tech',
            'address'     => '131.112.28.0',
            'netmask'     => '255.255.253.0',
            'gateway'     => '131.112.28.254',
            'dns'         => [ '131.112.125.58' ],
            'ntp'         => [ 'ntp1.noc.titech.ac.jp' ],
            'lease'       => [
                              { 'name' => 'vm00.m.gsic.titech.ac.jp',
                                'address' => '131.112.28.100' }
                             ],
            'interface'   => 'br0'
          }
        end

        let(:output_zone_vnets_hash) do
          hash = output_zone_hash.dup
          hash['network'] = [ output_vnet_hash, output_vnet_hash2 ]
          hash
        end

        it 'will generate just a zone when no network csv is given.' do
          yaml_doc = rgen.gen_zone_with_vnet(input_zone_csv)
          data = YAML.load(yaml_doc)
          data.should == output_zone_hash
        end

        it 'will generate a zone with a vnet when a network csv is given' do
          yaml_doc = rgen.gen_zone_with_vnet(input_zone_csv, input_vnet_csv)
          data = YAML.load(yaml_doc)
          data.should == output_zone_vnet_hash
        end

        it 'will generate a zone with two vnets when two network csv are given' do
          yaml_doc = rgen.gen_zone_with_vnet(input_zone_csv,
                                             input_vnet_csv, input_vnet_csv2)
          data = YAML.load(yaml_doc)
          data.should == output_zone_vnets_hash
        end
      end
    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
