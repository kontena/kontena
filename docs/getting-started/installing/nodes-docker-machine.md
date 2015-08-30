---
title: Nodes (with Docker Machine)
toc_order: 4
---

# Installing Kontena Nodes with Docker Machine

> Prerequisities: You'll need [Docker Machine](https://docs.docker.com/machine/) installed on your system.

It is possible to provision Kontena Nodes with Docker Machine. The only issue with Docker Machine provisioning is that it requires manual DNS configuration for each host.

## Provision a Docker Machine

You can use Docker Machine to provision a machine to the (cloud) platform of your choice. See Docker Machine documentation for details. In the example below, we'll provision a `virtualbox` machine.

```
$ docker-machine create --driver virtualbox kontena-node-1
```

## Start Kontena Agent

Once the machine is up and running, you are ready to install Kontena Agent. For this, you'll need `KONTENA_URI` and `KONTENA_TOKEN`. You can get this information with Kontena CLI.

```
$ kontena grid current
mygrid:
  uri: ws://192.168.66.100:8080
  token: Fs+IYJyOgpP80LMCy0tuHpOOhiPYTkdzaFy1onOY1jZxJ3bvCFEevUUT3dzWwkRmUt/Vj1RA1HCgY3QpLQ24aA==
  users: 1
  nodes: 1
  services: 2
  containers: 0
```

Next, start the Kontena Agent using the `uri` and `token`.

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

## Verify Installation

Once the Kontena Agent has been started, verify the node is correctly registered to Kontena Master.

```
$ kontena node list
```

## Configure DNS (optional)

If you want to use [Kontena Image Registry](../../using-kontena/image-registry.md), you must tweak DNS settings of the machine so that `docker0` ip is preferred name server.
