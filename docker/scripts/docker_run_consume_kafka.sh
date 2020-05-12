#!/usr/bin/env bash

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
set -u # nounset
set -e # errexit
set -E # errtrap
set -o pipefail

#
# Runs a kafka container with the console consumer for the appropriate topic.
# The consumer should quit when it has read all of the messages available.
#

function help {
  echo " "
  echo "usage: ${0}"
  echo "    --network-name                  [OPTIONAL] The Docker network name. Default: metron-bro-plugin-kafka_default"
  echo "    --offset                        [OPTIONAL] The kafka offset to read from. Default: -1"
  echo "    --kafka-topic                   [OPTIONAL] The kafka topic to consume from. Default: zeek"
  echo "    -h/--help                       Usage information."
  echo " "
}

NETWORK_NAME=metron-bro-plugin-kafka_default
OFFSET=-1
KAFKA_TOPIC=zeek

# handle command line options
for i in "$@"; do
  case $i in
  #
  # NETWORK_NAME
  #
  #   --network-name
  #
    --network-name=*)
      NETWORK_NAME="${i#*=}"
      shift # past argument=value
    ;;
  #
  # OFFSET
  #
  #   --offset
  #
    --offset=*)
      OFFSET="${i#*=}"
      shift # past argument=value
    ;;
  #
  # KAFKA_TOPIC
  #
  #   --kafka-topic
  #
    --kafka-topic=*)
      KAFKA_TOPIC="${i#*=}"
      shift # past argument=value
    ;;
  #
  # -h/--help
  #
    -h | --help)
      help
      exit 0
      shift # past argument with no value
    ;;

  #
  # Unknown option
  #
    *)
      UNKNOWN_OPTION="${i#*=}"
      echo "Error: unknown option: $UNKNOWN_OPTION"
      help
    ;;
  esac
done

docker run --rm --network "${NETWORK_NAME}" metron-bro-plugin-kafka_kafka \
  kafka-console-consumer.sh --topic "${KAFKA_TOPIC}" --offset "${OFFSET}" --partition 0 --bootstrap-server kafka-1:9092 --timeout-ms 1000
rc=$?; if [[ ${rc} != 0 ]]; then
  exit ${rc}
fi

