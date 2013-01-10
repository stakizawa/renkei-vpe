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


require 'spec_helper'
require 'renkei-vpe-server/model/vm_type'

module RenkeiVPE
  module Model

    describe VMType do
      Log_File = 'vm_type_spec.log'
      DB_File  = 'vm_type_spec.db'

      Type0 = [ 0, 'small' , 1, 1024, 'small size VM' , 1 ]
      Type1 = [ 1, 'medium', 2, 2048, 'medium size VM', 4 ]

      Type0_SQL = "(0,'small',1,1024,'small size VM',1)"
      Type1_SQL = "(1,'medium',2,2048,'medium size VM',4)"

      def run_sql(sql)
        system("sqlite3 #{DB_File} \"#{sql}\" 2>/dev/null")
      end

      def data_count(cond=nil)
        sql = "SELECT COUNT(*) FROM vm_types"
        if cond
          sql += " WHERE #{cond};"
        else
          sql += ';'
        end
        out = `sqlite3 #{DB_File} \"#{sql}\" 2>/dev/null`
        return out.split(/\s+/)[2].to_i  # COUNT(*) = 1
      end

      def gen_type_from_native_sql(id)
        sql = "SELECT * FROM vm_types WHERE id=#{id}"
        out = `sqlite3 #{DB_File} \"#{sql}\" 2>/dev/null`
        attr = []
        out.each_line do |e|
          if /.+=(.+)$/ =~ e
            attr << $1.strip
          end
        end
        VMType.gen_instance(attr)
      end

      before(:all) do
        RenkeiVPE::Logger.init(Log_File)
      end

      after(:all) do
        RenkeiVPE::Logger.finalize
        FileUtils.rm_rf(Log_File)
      end

      before(:each) do
        Database.file = DB_File
        VMType.create_table_if_necessary
        [ "INSERT INTO vm_types VALUES #{Type0_SQL};",
          "INSERT INTO vm_types VALUES #{Type1_SQL};" ].each do |e|
          run_sql(e)
        end
      end

      after(:each) do
        FileUtils.rm_rf(DB_File)
      end

      # here tests start

      context '.table_name' do
        it 'will return name of table.' do
          VMType.table_name.should == 'vm_types'
        end
      end

      context '.create_table_if_necessary' do
        it 'will not creata table if there is a table with the same name.' do
          VMType.create_table_if_necessary.should be_false
        end
      end

      context '.find' do
        it 'will return an array that contains found data.' do
          condition = 'cpu=1'
          result = VMType.find(condition)
          result.class.should == Array
          result.size.should  == 1
          result[0].id.should == 0
        end

        it 'will return an empty array if data is not found.' do
          condition = "name='large'"
          result = VMType.find(condition)
          result.class.should == Array
          result.size.should  == 0
        end
      end

      context '.find_by_id' do
        it 'will return an array that contains found data.' do
          result = VMType.find_by_id(1)
          result.class.should == Array
          result.size.should  == 1
          result[0].name.should == 'medium'
        end

        it 'will return an empty array if data is not found.' do
          result = VMType.find_by_id(2)
          result.class.should == Array
          result.size.should  == 0
        end
      end

      context '.find_by_name' do
        it 'will return an array that contains found data.' do
          result = VMType.find_by_name('small')
          result.class.should == Array
          result.size.should  == 1
          result[0].id.should == 0
        end

        it 'will return an empty array if data is not found.' do
          result = VMType.find_by_name('large')
          result.class.should == Array
          result.size.should  == 0
        end
      end

      context '.find_by_id_or_name' do
        it 'will return an array that contains found data.' do
          # call find_by_id
          result = VMType.find_by_id_or_name('1')
          result.class.should == Array
          result.size.should  == 1
          result[0].name.should == 'medium'
          # call find_by_name
          result = VMType.find_by_id_or_name('small')
          result.class.should == Array
          result.size.should  == 1
          result[0].id.should == 0
        end

        it 'will return an empty array if data is not found.' do
          # call find_by_id
          result = VMType.find_by_id_or_name('2')
          result.class.should == Array
          result.size.should  == 0
          # call find_by_name
          result = VMType.find_by_id_or_name('large')
          result.class.should == Array
          result.size.should  == 0
        end
      end

      context '#create' do
        it 'will create vm type on the table.' do
          t = VMType.new
          t.name        = 'large'
          t.cpu         = 4
          t.memory      = 4096
          t.description = ''
          t.weight      = 16
          t.create
          data_count.should == 3
        end

        it 'will not create vm type on the table when name conflits.' do
          # name conflicts
          t = VMType.new
          t.name        = 'small'
          t.cpu         = 1
          t.memory      = 2048
          t.description = ''
          t.weight      = 2
          lambda { t.create }.should raise_error(SQLite3::SQLException)
          data_count.should == 2
        end
      end

      context '#update' do
        it 'will update vm type on the table.' do
          # by default small.weight is 1
          t = VMType.gen_instance(Type0)
          t.weight.should == 1
          t.weight = 4
          t.update
          # after updating, small.weight is 4
          t = gen_type_from_native_sql(Type0[0])
          t.weight.should == 4
        end
      end

      context '#delete' do
        it 'will delete vm type from the table.' do
          t = VMType.gen_instance(Type1)
          t.delete
          data_count.should == 1
        end

        it 'will not delete vm type if vm type is not found.' do
          t = VMType.gen_instance(Type1)
          t.delete  # vm type is deleted only here
          t.delete
          data_count.should_not == 0
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
