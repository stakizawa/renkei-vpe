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
require 'renkei-vpe-server/resource_file'

module RenkeiVPE
  module ResourceFile

    describe Parser do
      let(:simple_hash_yaml) do <<EOS
Aa: a
bB: b
c1: c
D2: d
EOS
      end

      let(:simple_hash_data) do
        {
          'AA' => 'a',
          'BB' => 'b',
          'C1' => 'c',
          'D2' => 'd'
        }
      end

      let(:simple_array_yaml) do <<EOS
- a
- b
- 1
EOS
      end

      let(:simple_array_data) do
        [ 'a', 'b', 1 ]
      end

      let(:hash_of_array_yaml) do <<EOS
Aa: a
bB:
 - 1
 - 2
EOS
      end

      let(:hash_of_array_data) do
        {
          'AA' => 'a',
          'BB' => [ 1, 2 ]
        }
      end

      let(:hash_of_array_of_hash_yaml) do <<EOS
Aa: a
bB:
 - 1
 - 2
c1:
 - 1a: x
   2b: y
 - a1: xx
   b2: yy
EOS
      end

      let(:hash_of_array_of_hash_data) do
        {
          'AA' => 'a',
          'BB' => [ 1, 2 ],
          'C1' => [ { '1A' => 'x' , '2B' => 'y'  },
                    { 'A1' => 'xx', 'B2' => 'yy' } ]
        }
      end

      let(:hash_of_array_of_hash_of_array_yaml) do <<EOS
Aa: a
bB:
 - 1
 - 2
c1:
 - 1a: x
   2b: y
 - a1: xx
   b2: yy
   c3:
    - xxx
    - yyy
EOS
      end

      let(:hash_of_array_of_hash_of_array_data) do
        {
          'AA' => 'a',
          'BB' => [ 1, 2 ],
          'C1' => [ { '1A' => 'x' , '2B' => 'y'  },
                    { 'A1' => 'xx',
                      'B2' => 'yy',
                      'C3' => [ 'xxx', 'yyy' ] } ]
        }
      end

      let(:err1_yaml) do <<EOS
a: 1;a
EOS
      end

      let(:err2_yaml) do <<EOS
a: 1#a
EOS
      end

      context '#load_yaml' do
        it 'will generate a simple hash whose keys are capitalized.' do
          data = Parser.load_yaml(simple_hash_yaml)
          data.class.should == Hash
          data.should == simple_hash_data
        end

        it 'will generate a simple array.' do
          data = Parser.load_yaml(simple_array_yaml)
          data.class.should == Array
          data.should == simple_array_data
        end

        it 'will generate a hash whose values are arrays.' do
          data = Parser.load_yaml(hash_of_array_yaml)
          data.class.should == Hash
          data['BB'].class.should == Array
          data.should == hash_of_array_data
        end

        it 'will generate a hash whose values are arrays of hashs.' do
          data = Parser.load_yaml(hash_of_array_of_hash_yaml)
          data.class.should == Hash
          data['BB'].class.should == Array
          data['C1'].class.should == Array
          data['C1'][0].class.should == Hash
          data.should == hash_of_array_of_hash_data
        end

        it 'will generate a hash whose values are arrays of hashs of arrays.' do
          data = Parser.load_yaml(hash_of_array_of_hash_of_array_yaml)
          data.class.should == Hash
          data['BB'].class.should == Array
          data['C1'].class.should == Array
          data['C1'][1].class.should == Hash
          data['C1'][1]['C3'].class.should == Array
          data.should == hash_of_array_of_hash_of_array_data
        end

        it "will raise with a yaml whose values include ';'." do
          lambda do
            Parser.load_yaml(err1_yaml)
          end.should raise_error(RuntimeError)
        end

        it "will raise with a yaml whose values include '#'." do
          lambda do
            Parser.load_yaml(err2_yaml)
          end.should raise_error(RuntimeError)
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
