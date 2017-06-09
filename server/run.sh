#!/bin/sh

echo "** Starting Kontena Master version `cat VERSION` **"
exec puma -p ${PORT:-9292} -e production
