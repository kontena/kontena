#!/bin/sh

set -uex

## docker-compose
DOCKER_COMPOSE_VERSION=1.11.1

[ -d /opt/bin ] || sudo install -d /opt/bin

[ -d /opt/docker-compose_$DOCKER_COMPOSE_VERSION ] || sudo install -d /opt/docker-compose_$DOCKER_COMPOSE_VERSION
[ -d /opt/docker-compose_$DOCKER_COMPOSE_VERSION/bin ] || sudo install -d /opt/docker-compose_$DOCKER_COMPOSE_VERSION/bin
[ -e /opt/docker-compose_$DOCKER_COMPOSE_VERSION/bin/docker-compose ] || (
  curl -o /tmp/docker-compose -sL https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m`
  sudo install -m 755 -t /opt/docker-compose_$DOCKER_COMPOSE_VERSION/bin /tmp/docker-compose
)

sudo ln -sf /opt/docker-compose_$DOCKER_COMPOSE_VERSION/bin/docker-compose /opt/bin/docker-compose
