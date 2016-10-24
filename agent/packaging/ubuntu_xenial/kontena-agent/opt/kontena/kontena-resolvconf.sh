#!/bin/bash

interface_inet(){
  ip -4 -o address show dev $1 scope global | awk 'match($0, /inet ([0-9.]+)/, a) { print a[1] }'
}

log() {
  echo "$*" >&2
}

RESOLVCONF=lo.kontena-docker

case "$1" in
  start)
    NAMESERVER=$(interface_inet docker0)

    log "Adding resolvconf ${RESOLVCONF}: nameserver=${NAMESERVER}"

    (
      if [ -n "$NAMESERVER" ]; then
        echo "nameserver $NAMESERVER"
      fi
    ) | resolvconf -a ${RESOLVCONF}

    ;;

  stop)
    log "Deleting resolvconf ${RESOLVCONF}"

    resolvconf -d ${RESOLVCONF} || true
    ;;

  *)
esac
