#!/bin/sh
if [ -n "$SSL_CERT" ]; then
  SSL_CERT=$(awk 1 ORS='\\n' $SSL_CERT)
else
  SSL_CERT="**None**"
fi
/usr/bin/docker run --name=kontena-server-haproxy \
  --link kontena-server-api:kontena-server-api \
  -e SSL_CERT="$SSL_CERT" \
  -p 80:80 -p 443:443 kontena/haproxy:latest
