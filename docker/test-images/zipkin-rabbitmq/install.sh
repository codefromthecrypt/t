#!/bin/sh
#
# Copyright 2015-2023 The OpenZipkin Authors
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
# in compliance with the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied. See the License for the specific language governing permissions and limitations under
# the License.
#

set -eux

echo "*** Installing RabbitMQ"
apk add --update --no-cache rabbitmq-server=~${RABBITMQ_SERVER_VERSION} rabbitmq-c-utils=~${RABBITMQ_C_UTILS_VERSION}

echo "*** Ensuring guest can access RabbitMQ from any hostname"
mkdir -p /etc/rabbitmq/
echo "loopback_users.guest = false" >> /etc/rabbitmq/rabbitmq.conf
chown -R rabbitmq /var/lib/rabbitmq /etc/rabbitmq

export RABBITMQ_FEATURE_FLAGS=classic_mirrored_queue_version,classic_queue_type_delivery_support,direct_exchange_routing_v2,feature_flags_v2,implicit_default_bindings,listener_records_in_ets,maintenance_mode_status,quorum_queue,restart_streams,stream_queue,stream_sac_coordinator_unblock_group,stream_single_active_consumer,tracking_records_in_ets,user_limits,virtual_host_metadata

echo "*** Starting RabbitMQ"
rabbitmq-server &
temp_rabbitmq_pid=$!

# Excessively long timeout to avoid having to create an ENV variable, decide its name, etc.
timeout=180
echo "Will wait up to ${timeout} seconds for RabbitMQ to come up before configuring"
while [ "$timeout" -gt 0 ] && kill -0 ${temp_rabbitmq_pid} && ! rabbitmqctl status > /dev/null 2>&1; do
    sleep 1
    timeout=$(($timeout - 1))
done

cat /var/log/rabbitmq/rabbit@buildkitsandbox.log
cat /etc/rabbitmq/rabbitmq.conf

echo "*** Adding zipkin queue"
amqp-declare-queue -q zipkin

echo "*** Stopping RabbitMQ"
kill ${temp_rabbitmq_pid}
wait

echo "*** Cleaning Up"
rm /var/log/rabbitmq/*
