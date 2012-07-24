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


require 'thread'

class ReadWriteLock
  def initialize
    @reading_readers = 0
    @waiting_writers = 0
    @writing_writers = 0
    @prefer_writer   = true
    @m = Mutex.new
    @cv = ConditionVariable.new
  end

  def read_lock
    @m.synchronize do
      while (@writing_writers > 0 || (@prefer_writer && @waiting_writers > 0)) do
        @cv.wait(@m)
      end
      @reading_readers += 1
    end
  end

  def read_unlock
    @m.synchronize do
      @reading_readers -= 1
      @prefer_writer  = true
      @cv.broadcast
    end
  end

  def write_lock
    @m.synchronize do
      @waiting_writers += 1
      begin
        while (@reading_readers > 0 || @writing_writers > 0) do
          @cv.wait(@m)
        end
      ensure
        @waiting_writers -= 1
      end
      @writing_writers += 1
    end
  end

  def write_unlock
    @m.synchronize do
      @writing_writers -= 1
      @prefer_writer  = false
      @cv.broadcast
    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
