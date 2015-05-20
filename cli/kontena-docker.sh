#!/bin/sh

docker inspect kontena-cli-data > /dev/null 2>&1 ||
  docker create --name kontena-cli-data kontena/cli:latest > /dev/null

docker run -it --rm --volumes-from kontena-cli-data kontena/cli:latest $@
