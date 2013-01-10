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
require 'fileutils'
require 'renkei-vpe-server/model/base'

module RenkeiVPE

  describe Database do
    Log_File = 'base_spec.log'
    DB_File  = 'base_spec.db'

    Table_Name   = 'base_spec'
    Table_Schema = <<EOS
CREATE TABLE #{Table_Name} (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  name    VARCHAR(256) UNIQUE,
  enabled INTEGER
);
EOS
    Name0        = 'test0'
    Name1        = 'test1'
    Name2        = 'test2'
    Name3        = 'test3'

    def run_sql(sql)
      system("sqlite3 #{DB_File} \"#{sql}\" 2>/dev/null")
    end

    def data_count(cond=nil)
      sql = "SELECT COUNT(*) FROM #{Table_Name}"
      if cond
        sql += " WHERE #{cond};"
      else
        sql += ';'
      end
      out = `sqlite3 #{DB_File} \"#{sql}\" 2>/dev/null`
      return out.split(/\s+/)[2].to_i  # COUNT(*) = 1
    end

    before(:all) do
      RenkeiVPE::Logger.init(Log_File)
    end

    after(:all) do
      RenkeiVPE::Logger.finalize
      FileUtils.rm_rf(Log_File)
    end

    before(:each) do
      run_sql(Table_Schema)
      [ "INSERT INTO #{Table_Name} VALUES (0, '#{Name0}', 1);",
        "INSERT INTO #{Table_Name} VALUES (1, '#{Name1}', 0);",
        "INSERT INTO #{Table_Name} VALUES (2, '#{Name2}', 1);",
        "INSERT INTO #{Table_Name} VALUES (3, '#{Name3}', 0);" ].each do |e|
        run_sql(e)
        Database.file = DB_File
      end
    end

    after(:each) do
      FileUtils.rm_rf(DB_File)
    end

    context '.file' do
      it 'will return database file path.' do
        Database.file.should == DB_File
      end
    end

    context '.execute' do
      # Test for its work ###################################################
      it 'will insert data when a correct sql is given.' do
        sql = "INSERT INTO #{Table_Name} VALUES (4, 'test4', 1)"
        val = Database.execute(sql)
        data_count('id=4').should == 1
      end

      it 'will raise when a given insert sql does not match the schema.' do
        sql = "INSERT INTO #{Table_Name} VALUES (4, 'test4', 1, 0)"
        lambda do
          Database.execute(sql)
        end.should raise_error(SQLite3::SQLException)
      end

      it 'will raise when a given insert sql contains used id.' do
        sql = "INSERT INTO #{Table_Name} VALUES (0, 'test4', 1)"
        lambda do
          Database.execute(sql)
        end.should raise_error(SQLite3::SQLException)
      end

      it 'will raise when a given sql contains syntax error.' do
        sql = "INSERT INTO #{Table_Name} VALUES (4, 'test4' 1)"
        lambda do
          Database.execute(sql)
        end.should raise_error(SQLite3::SQLException)
      end

      # Test for return value ###############################################
      it 'will return an array when block is not given.' do
        sql = "SELECT COUNT(*) FROM #{Table_Name} WHERE enabled=1"
        row = Database.execute(sql)
        row.class.should == Array
        row.size.should == 1
        row[0][0].should == '2'

        sql = "SELECT * FROM #{Table_Name} WHERE enabled=1"
        row = Database.execute(sql)
        row.class.should == Array
        row.size.should == 2
      end

      it 'will iterate data when block is given.' do
        sql = "SELECT COUNT(*) FROM #{Table_Name} WHERE enabled=1"
        blk = lambda do
          result = nil
          Database.execute(sql) do |r|
            result = r[0]
          end
          result
        end
        blk.call.should == '2'

        sql = "SELECT * FROM #{Table_Name} WHERE enabled=1"
        blk = lambda do
          result = []
          Database.execute(sql) do |r|
            result << r
          end
          result
        end
        blk.call.size.should == 2
      end
    end

    context '.transaction' do
      it 'will delete all data from the table when transaction successes.' do
        sqls = [ "DELETE FROM #{Table_Name} WHERE name='#{Name0}'",
                 "DELETE FROM #{Table_Name} WHERE name='#{Name1}'",
                 "DELETE FROM #{Table_Name} WHERE name='#{Name2}'",
                 "DELETE FROM #{Table_Name} WHERE name='#{Name3}'" ]
        Database.transaction(*sqls)
        data_count.should == 0
      end

      it 'will not delete any data from the table when transaction failes.' do
        sqls = [ "DELETE FROM #{Table_Name} WHERE name='#{Name0}'",
                 "DELETE FROM #{Table_Name} WHERE test='#{Name0}'",
                 "DELETE FROM #{Table_Name} WHERE name='#{Name2}'",
                 "DELETE FROM #{Table_Name} WHERE name='#{Name3}'" ]
        lambda do
          Database.transaction(*sqls)
        end.should raise_error(SQLite3::SQLException)
        data_count.should == 4
      end
    end
  end

end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
