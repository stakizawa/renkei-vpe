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
require 'renkei-vpe-server/model/transfer'

module RenkeiVPE
  module Model

    describe Transfer do
      Log_File = 'transfer_spec.log'
      DB_File  = 'transfer_spec.db'

      Test_Time = Time.now.to_i - 3600

      # meanings items
      # 0: id   : session id
      # 1: name : session name
      # 2: type : transfer type
      # 3: path : server side file path
      # 4: size : size to transfer
      # 5: date : date when the session created
      # 5: done : done flag
      GET = [ 0, 'e756894bec8b5769564de5f773bdbf169a72a1af', 'get',
              '/usr/rpop/opennebula/var/images/3e7cc11b421370', 591140864,
              Test_Time, 0 ]
      PUT = [ 1, 'dc7dda0887ce9c31ce10c7d2c2b42d6cbe6b9b71', 'put',
              '/usr/rpop/renkei-vpe/var/transfer/84e261ac0f85', 591140864,
              Test_Time, 0 ]

      GET_SQL = "(0,'e756894bec8b5769564de5f773bdbf169a72a1af','get','/usr/rpop/opennebula/var/images/3e7cc11b421370',591140864,#{Test_Time},0)"
      PUT_SQL = "(1,'dc7dda0887ce9c31ce10c7d2c2b42d6cbe6b9b71','put','/usr/rpop/renkei-vpe/var/transfer/84e261ac0f85',591140864,#{Test_Time},0)"

      def run_sql(sql)
        system("sqlite3 #{DB_File} \"#{sql}\" 2>/dev/null")
      end

      def data_count(cond=nil)
        sql = "SELECT COUNT(*) FROM transfers"
        if cond
          sql += " WHERE #{cond};"
        else
          sql += ';'
        end
        out = `sqlite3 #{DB_File} \"#{sql}\" 2>/dev/null`
        return out.split(/\s+/)[2].to_i  # COUNT(*) = 1
      end

      def gen_transfer_from_native_sql(id)
        sql = "SELECT * FROM transfers WHERE id=#{id}"
        out = `sqlite3 #{DB_File} \"#{sql}\" 2>/dev/null`
        attr = []
        out.each_line do |e|
          if /.+=(.+)$/ =~ e
            attr << $1.strip
          end
        end
        Transfer.gen_instance(attr)
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
        Transfer.create_table_if_necessary
        [ "INSERT INTO transfers VALUES #{GET_SQL};",
          "INSERT INTO transfers VALUES #{PUT_SQL};" ].each do |e|
          run_sql(e)
        end
      end

      after(:each) do
        FileUtils.rm_rf(DB_File)
      end

      context '.table_name' do
        it 'will return name of table.' do
          Transfer.table_name.should == 'transfers'
        end
      end

      context '.create_table_if_necessary' do
        it 'will not creata table if there is a table with the same name.' do
          Transfer.create_table_if_necessary.should be_false
        end
      end

      context '.find' do
        it 'will return an array that contains found data.' do
          condition = "type='get'"
          result = Transfer.find(condition)
          result.class.should == Array
          result.size.should  == 1
          result[0].id.should == 0
        end

        it 'will return an empty array if data is not found.' do
          condition = "name='3a56d94bec8b57f9564de5f773bdbf1e9a72a1af'"
          result = Transfer.find(condition)
          result.class.should == Array
          result.size.should  == 0
        end
      end

      context '.find_by_id' do
        it 'will return an array that contains found data.' do
          result = Transfer.find_by_id(1)
          result.class.should == Array
          result.size.should  == 1
          result[0].name.should == 'dc7dda0887ce9c31ce10c7d2c2b42d6cbe6b9b71'
        end

        it 'will return an empty array if data is not found.' do
          result = Transfer.find_by_id(2)
          result.class.should == Array
          result.size.should  == 0
        end
      end

      context '.find_by_name' do
        it 'will return an array that contains found data.' do
          result = Transfer.find_by_name('dc7dda0887ce9c31ce10c7d2c2b42d6cbe6b9b71')
          result.class.should == Array
          result.size.should  == 1
          result[0].id.should == 1
        end

        it 'will return an empty array if data is not found.' do
          result = Transfer.find_by_name('3a56d94bec8b57f9564de5f773bdbf1e9a72a1af')
          result.class.should == Array
          result.size.should  == 0
        end
      end

      context '.find_by_id_or_name' do
        it 'will return an array that contains found data.' do
          # call find_by_id
          result = Transfer.find_by_id_or_name('1')
          result.class.should == Array
          result.size.should  == 1
          result[0].name.should == 'dc7dda0887ce9c31ce10c7d2c2b42d6cbe6b9b71'
          # call find_by_name
          result = Transfer.find_by_id_or_name('dc7dda0887ce9c31ce10c7d2c2b42d6cbe6b9b71')
          result.class.should == Array
          result.size.should  == 1
          result[0].id.should == 1
        end

        it 'will return an empty array if data is not found.' do
          # call find_by_id
          result = Transfer.find_by_id_or_name('2')
          result.class.should == Array
          result.size.should  == 0
          # call find_by_name
          result = Transfer.find_by_id_or_name('3a56d94bec8b57f9564de5f773bdbf1e9a72a1af')
          result.class.should == Array
          result.size.should  == 0
        end
      end

      context '.cleanup_before' do
        it 'will delete and return data that are older than specified time.' do
          # delete all data
          result = Transfer.cleanup_before(0)
          data_count.should == 0
          result.class.should == Array
          result.size.should == 2
        end

        it 'will do nothing when specified time is older than any data.' do
          result = Transfer.cleanup_before(360000)
          data_count.should == 2
          result.class.should == Array
          result.size.should == 0
        end
      end


      context '#create' do
        it 'will create transfer on the table.' do
          t = Transfer.new
          t.name = 'test'
          t.type = 'get'
          t.path = '/this/is/path'
          t.size = 12345
          t.create
          data_count.should == 3
        end
      end

      context '#update' do
        it 'will update transfer on the table.' do
          # by default transfer.size is 591140864
          t = Transfer.gen_instance(PUT)
          t.size.should == 591140864
          t.size = 1024
          t.update
          # after updating, transfer.size is 1024
          t = gen_transfer_from_native_sql(PUT[0])
          t.size.should == 1024
        end
      end

      context '#delete' do
        it 'will delete transfer from the table.' do
          t = Transfer.gen_instance(GET)
          t.delete
          data_count.should == 1
        end

        it 'will not delete transfer if transfer is not found.' do
          t = Transfer.gen_instance(GET)
          t.delete  # transfer is deleted only here
          t.delete
          data_count.should_not == 0
        end
      end

      context '#set_done' do
        it 'will set done instance value and write it to DB.' do
          t = Transfer.gen_instance(PUT)
          t.instance_eval do
            @done.should == 0
          end
          t.set_done
          # after #set_done is called, transfer.done in memory is 1
          t.instance_eval do
            @done.should == 1
          end
          # after #set_done is called, transfer.done in DB is 1
          t = gen_transfer_from_native_sql(PUT[0])
          t.instance_eval do
            @done.should == 1
          end
        end
      end

      context '#is_done?' do
        it 'will return true if done instance value is 1.' do
          t = Transfer.gen_instance(PUT)
          t.is_done?.should be_false
          t.instance_eval do
            @done = 1
          end
          # after done is set 1, transfer.is_done? return true
          t.is_done?.should be_true
        end

        it 'will return true if set_done is called once.' do
          t = Transfer.gen_instance(PUT)
          t.is_done?.should be_false
          t.set_done
          t.is_done?.should be_true
          # read from DB
          t = gen_transfer_from_native_sql(PUT[0])
          t.is_done?.should be_true
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
