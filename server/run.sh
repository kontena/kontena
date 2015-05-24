#!/bin/sh

echo "Updating MongoDB indexes... "
rake db:mongoid:create_indexes > /dev/null

exec puma -p 9292 -e production
