#!/bin/sh
set -eu

mkdir -p /host/opt/kontena/bin
cp /usr/bin/cadvisor /host/opt/kontena/bin/cadvisor

COMMAND="nsenter --target 1 --mount --uts --net --pid -- /opt/kontena/bin/cadvisor --logtostderr $@"
# Launch cadvisor
exec $COMMAND
