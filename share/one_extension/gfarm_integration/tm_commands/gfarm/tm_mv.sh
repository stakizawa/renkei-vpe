#!/bin/bash
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


SRC=$1
DST=$2

if [ -z "${ONE_LOCATION}" ]; then
    TMCOMMON=/usr/lib/one/mads/tm_common.sh
    GFARMRC=/etc/one/tm_gfarm/tm_gfarmrc
else
    TMCOMMON=$ONE_LOCATION/lib/mads/tm_common.sh
    GFARMRC=$ONE_LOCATION/etc/tm_gfarm/tm_gfarmrc
fi

. $TMCOMMON
. $GFARMRC

SRC_PATH=`arg_path $SRC`
DST_PATH=`arg_path $DST`

SRC_HOST=`arg_host $SRC`
DST_HOST=`arg_host $DST`

DST_DIR=`dirname $DST_PATH`

log "Moving $1 $2"
GF_DST_PATH=`gf_mv_target $DST_PATH`
exec_and_log "$SSH $SRC_HOST $GFREG $SRC_PATH $GF_DST_PATH"
exec_and_log "$SSH $SRC_HOST rm -rf $SRC_PATH"
