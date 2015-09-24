---
title: Nodes (manually)
toc_order: 5
---

# Installing Kontena Nodes Manually

Kontena Nodes may be installed manually to any Linux machine capable of running Docker Engine. In order to connect nodes to your Kontena Master, you'll need `KONTENA_URI` and `KONTENA_TOKEN`. You can get this information with Kontena CLI.

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

## CoreOS

Example cloud-config that can be used as a basis for CoreOS installation. Replace `KONTENA_URI` and `KONTENA_TOKEN` to match your configuration.

```yaml
#cloud-config
write_files:
  - path: /etc/kontena-agent.env
    permissions: 0600
    owner: root
    content: |
      KONTENA_URI="<kontena master websocket uri>"
      KONTENA_TOKEN="<grid_token>"
      KONTENA_PEER_INTERFACE=eth1
      KONTENA_VERSION=latest
  - path: /etc/systemd/system/docker.service.d/50-kontena.conf
    content: |
        [Service]
        Environment='DOCKER_OPTS=--insecure-registry="10.81.0.0/19" --bip="10.255.0.1/16"'
coreos:
  units:
    - name: 00-eth.network
      runtime: true
      content: |
        [Match]
        Name=eth*
        [Network]
        DHCP=yes
        DNS=10.255.0.1
        DNS=8.8.8.8
        DNS=8.8.4.4
        DOMAINS=kontena.local
        [DHCP]
        UseDNS=false
    - name: etcd2.service
      command: start
      enable: true
      content: |
        Description=etcd 2.0
        After=docker.service
        [Service]
        Restart=always
        RestartSec=5
        ExecStart=/usr/bin/docker logs --tail=10 -f kontena-etcd
    - name: 10-weave.network
      runtime: false
      content: |
        [Match]
        Type=bridge
        Name=weave*

        [Network]
    - name: kontena-agent.service
      command: start
      enable: true
      content: |
        [Unit]
        Description=kontena-agent
        After=network-online.target
        After=docker.service
        Description=Kontena Agent
        Documentation=http://www.kontena.io/
        Requires=network-online.target
        Requires=docker.service

        [Service]
        Restart=always
        RestartSec=5
        EnvironmentFile=/etc/kontena-agent.env
        ExecStartPre=-/usr/bin/docker stop kontena-agent
        ExecStartPre=-/usr/bin/docker rm kontena-agent
        ExecStartPre=/usr/bin/docker pull kontena/agent:${KONTENA_VERSION}
        ExecStart=/usr/bin/docker run --name kontena-agent \
            -e KONTENA_URI=${KONTENA_URI} \
            -e KONTENA_TOKEN=${KONTENA_TOKEN} \
            -e KONTENA_PEER_INTERFACE=${KONTENA_PEER_INTERFACE} \
            -v=/var/run/docker.sock:/var/run/docker.sock \
            --net=host \
            kontena/agent:${KONTENA_VERSION}
```

**NOTE**: You should replace docker `--bip` address with something that is not conflicting with your infrastructure and set that ip as the default nameserver.

## Ubuntu 14.04

> Prerequisities: Docker 1.7 or later

### Install Kontena Ubuntu packages

```sh
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-agent
```

#### Configure agents during installation process

* The address of the Kontena server. Note! You must use WebSocket protocol: ws or wss for secured connections
* Grid token from the Kontena server

### Restart Docker

```sh
$ sudo restart docker
```

### Verify that agents are connected to server

```sh
$ kontena node list
```
