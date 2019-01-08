#!/usr/bin/env bash
# shellcheck disable=SC2010

#
#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#


shopt -s nocasematch

#
# For each file in the data directory and sub-directories ( if mapped ), this script will
# run bro -r with the local.bro configuration.
#

cd /root || exit 1
echo "================================" >>"${RUN_LOG_PATH}" 2>&1
if [ ! -d /root/data ]; then
  echo "DATA_PATH has not been set and mapped" >>"${RUN_LOG_PATH}" 2>&1
  exit 1
fi

echo "==========DATA_PATH=============="
ls /root/data
echo "================================="

# Process all pcaps in the data directory and sub directories
find /root/data -type f -name "*.pcap*" -exec echo "processing" '{}' \; -exec bro -r '{}' /usr/local/bro/share/bro/site/local.bro -C \;

