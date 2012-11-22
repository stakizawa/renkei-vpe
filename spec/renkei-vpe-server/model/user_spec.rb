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
require 'renkei-vpe-server/model/user'

module RenkeiVPE
  module Model

    describe User do
      Log_File = 'user_spec.log'
      DB_File  = 'user_spec.db'

      User0 = [ 0, 0, 'popadmin', 1, '1;2;3', 10, '1;1;1' ]
      User1 = [ 1, 1, 'test'    , 0, ''     , 0 , ''      ]

      User0_SQL = "(0,0,'popadmin',1,'1;2;3',10,'1;1;1')"
      User1_SQL = "(1,1,'test',0,'',0,'')"

      def run_sql(sql)
        system("sqlite3 #{DB_File} \"#{sql}\" 2>/dev/null")
      end

      def data_count(cond=nil)
        sql = "SELECT COUNT(*) FROM users"
        if cond
          sql += " WHERE #{cond};"
        else
          sql += ';'
        end
        out = `sqlite3 #{DB_File} \"#{sql}\" 2>/dev/null`
        return out.split(/\s+/)[2].to_i  # COUNT(*) = 1
      end

      def gen_user_from_native_sql(id)
        sql = "SELECT * FROM users WHERE id=#{id}"
        out = `sqlite3 #{DB_File} \"#{sql}\" 2>/dev/null`
        attr = []
        out.each_line do |e|
          if /.+=(.+)$/ =~ e
            attr << $1.strip
          end
        end
        User.gen_instance(attr)
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
        User.create_table_if_necessary
        [ "INSERT INTO users VALUES #{User0_SQL};",
          "INSERT INTO users VALUES #{User1_SQL};" ].each do |e|
          run_sql(e)
        end
      end

      after(:each) do
        FileUtils.rm_rf(DB_File)
      end

      context '.table_name' do
        it 'will return name of table.' do
          User.table_name.should == 'users'
        end
      end

      context '.create_table_if_necessary' do
        it 'will not creata table if there is a table with the same name.' do
          User.create_table_if_necessary.should be_false
        end
      end

      context '.find' do
        it 'will return an array that contains found data.' do
          condition = 'enabled=1'
          result = User.find(condition)
          result.class.should == Array
          result.size.should  == 1
          result[0].id.should == 0
        end

        it 'will return an empty array if data is not found.' do
          condition = "name='testtest'"
          result = User.find(condition)
          result.class.should == Array
          result.size.should  == 0
        end
      end

      context '.find_by_id' do
        it 'will return an array that contains found data.' do
          result = User.find_by_id(1)
          result.class.should == Array
          result.size.should  == 1
          result[0].name.should == 'test'
        end

        it 'will return an empty array if data is not found.' do
          result = User.find_by_id(2)
          result.class.should == Array
          result.size.should  == 0
        end
      end

      context '.find_by_name' do
        it 'will return an array that contains found data.' do
          result = User.find_by_name('test')
          result.class.should == Array
          result.size.should  == 1
          result[0].id.should == 1
        end

        it 'will return an empty array if data is not found.' do
          result = User.find_by_name('testtest')
          result.class.should == Array
          result.size.should  == 0
        end
      end

      context '.find_by_id_or_name' do
        it 'will return an array that contains found data.' do
          # call find_by_id
          result = User.find_by_id_or_name('1')
          result.class.should == Array
          result.size.should  == 1
          result[0].name.should == 'test'
          # call find_by_name
          result = User.find_by_id_or_name('test')
          result.class.should == Array
          result.size.should  == 1
          result[0].id.should == 1
        end

        it 'will return an empty array if data is not found.' do
          # call find_by_id
          result = User.find_by_id_or_name('2')
          result.class.should == Array
          result.size.should  == 0
          # call find_by_name
          result = User.find_by_id_or_name('testtest')
          result.class.should == Array
          result.size.should  == 0
        end
      end

      context '#create' do
        it 'will create user on the table.' do
          u = User.new
          u.oid = 2
          u.name = 'testtest'
          u.enabled = 1
          u.create
          data_count.should == 3
        end

        it 'will not create user on the table when oid or name conflits.' do
          # oid conflicts
          u = User.new
          u.oid = 0
          u.name = 'testtest'
          lambda { u.create }.should raise_error(SQLite3::SQLException)
          data_count.should == 2

          # name conflicts
          u = User.new
          u.oid = 2
          u.name = 'test'
          lambda { u.create }.should raise_error(SQLite3::SQLException)
          data_count.should == 2
        end
      end

      context '#update' do
        it 'will update user on the table.' do
          # by default popadmin.enabled is 1
          u = User.gen_instance(User0)
          u.enabled.should == 1
          u.enabled = 0
          u.update
          # after updating, popadmin.enabled is 0
          u = gen_user_from_native_sql(User0[0])
          u.enabled.should == 0
        end
      end

      context '#delete' do
        it 'will delete user from the table.' do
          u = User.gen_instance(User1)
          u.delete
          data_count.should == 1
        end

        it 'will not delete user if user is not found.' do
          u = User.gen_instance(User1)
          u.delete  # user is deleted only here
          u.delete
          data_count.should_not == 0
        end
      end

      context '#modify_zone' do
        it 'will set a zone and its limit to user.' do
          u = User.gen_instance(User1)
          u.modify_zone(1, true, 1)
          u.update
          uu = gen_user_from_native_sql(User1[0])
          uu.zones.should  == '1'
          uu.limits.should == '1'

          u.modify_zone(2, true, 2)
          u.update
          uu = gen_user_from_native_sql(User1[0])
          uu.zones.should  == '1;2'
          uu.limits.should == '1;2'
        end

        it 'will remove a zone and its limit from user.' do
          u = User.gen_instance(User0)
          # remove zone 1, remain is 2
          u.modify_zone(1, false, -1)
          u.update
          uu = gen_user_from_native_sql(User0[0])
          uu.zones.should  == '2;3'
          uu.limits.should == '1;1'

          # remove zone 2, remain is 1
          u.modify_zone(2, false, -1)
          u.update
          uu = gen_user_from_native_sql(User0[0])
          uu.zones.should  == '3'
          uu.limits.should == '1'

          # remove zone 3, all zones are removed
          u.modify_zone(3, false, -1)
          u.update
          uu = gen_user_from_native_sql(User0[0])
          uu.zones.should  == ''
          uu.limits.should == ''
        end
      end

      context '#zones_in_array' do
        it 'will return zone ids in an array.' do
          u = gen_user_from_native_sql(User0[0])
          zs = u.zones_in_array
          zs.class.should == Array
          zs.size.should == 3
          zs[0].should == 1

          u = gen_user_from_native_sql(User1[0])
          zs = u.zones_in_array
          zs.class.should == Array
          zs.size.should == 0
        end
      end

      context '#limits_in_array' do
        it 'will return zone limits in an array' do
          u = gen_user_from_native_sql(User0[0])
          ls = u.limits_in_array
          ls.class.should == Array
          ls.size.should == 3
          ls[0].should == 1

          u = gen_user_from_native_sql(User1[0])
          ls = u.limits_in_array
          ls.class.should == Array
          ls.size.should == 0
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
