---
title: Nodes (with Docker Machine)
toc_order: 4
---

# Installing Kontena Nodes with Docker Machine

> Prerequisities: You'll need [Docker Machine](https://docs.docker.com/machine/) installed on your system.

## Provision a new Docker Machine:

```sh
$ docker-machine create --driver virtualbox kontena-node-1
```

## Start Kontena Agent:

```
$ eval "$(docker-machine env kontena-node-1)"
$ docker run -d --name kontena-agent \
    -e KONTENA_URI=<kontena master websocket address> \
    -e KONTENA_TOKEN=<kontena grid token> \
    -e KONTENA_PEER_INTERFACE=eth1 \
    -v=/var/run/docker.sock:/var/run/docker.sock \
    --net=host \
    kontena/agent:latest
```

If you want to use [Kontena Image Registry](../../using-kontena/image-registry.md), you must tweak Docker Machine dns settings so that `docker0` ip is preferred nameserver.

## Verify installation

Check that node is registered to Kontena Master:

```
$ kontena node list
```
