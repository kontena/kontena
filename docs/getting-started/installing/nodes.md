---
title: Installing Kontena Nodes
toc_order: 2
---

# Installing Kontena Nodes

## Installing with Kontena CLI

Kontena CLI may be used to provision new Kontena Nodes based on [CoreOS](https://coreos.com/using-coreos/), fully configured and ready for action! At the moment, you can provision Nodes to following platforms:

* Amazon AWS
* Microsoft Azure
* DigitalOcean
* Vagrant (local environment)

We are adding support for other platforms gradually based on your requests. If you'd like to see support for the platform you are using, please [post your request](https://github.com/kontena/kontena/issues) as an issue to our GitHub repository.

### Amazon AWS

```
Usage:
    kontena node aws create [OPTIONS]

Options:
    --name NAME                   Node name
    --access-key ACCESS_KEY       AWS access key ID
    --secret-key SECRET_KEY       AWS secret key
    --region REGION               EC2 Region (default: "eu-west-1")
    --zone ZONE                   EC2 Availability Zone (default: "a")
    --vpc-id VPC ID               Virtual Private Cloud (VPC) ID
    --subnet-id SUBNET ID         VPC option to specify subnet to launch instance into
    --key-pair KEY_PAIR           EC2 Key Pair
    --type SIZE                   Instance type (default: "t2.small")
    --storage STORAGE             Storage size (GiB) (default: "30")
    --version VERSION             Define installed Kontena version (default: "latest")
```

### Microsoft Azure

```
Usage:
    kontena node azure create [OPTIONS] [NAME]

Parameters:
    [NAME]                        Node name

Options:
    --subscription-id SUBSCRIPTION ID Azure subscription id
    --subscription-cert CERTIFICATE Path to Azure management certificate
    --size SIZE                   SIZE (default: "Small")
    --network NETWORK             Virtual Network name
    --subnet SUBNET               Subnet name
    --ssh-key SSH KEY             SSH private key file
    --password PASSWORD           Password
    --location LOCATION           Location (default: "West Europe")
    --version VERSION             Define installed Kontena version (default: "latest")
```

### Digital Ocean

```
Usage:
    kontena node digitalocean create [OPTIONS]

Options:
    --name NAME                   Node name
    --token TOKEN                 DigitalOcean API token
    --ssh-key SSH_KEY             Path to ssh public key
    --size SIZE                   Droplet size (default: "1gb")
    --region REGION               Region (default: "ams2")
    --version VERSION             Define installed Kontena version (default: latest)
```

### Vagrant

```
Usage:
    kontena node vagrant create [OPTIONS]

Options:
    --name NAME                   Node name
    --memory MEMORY               How much memory node has (default: 1024)
    --version VERSION             Define installed Kontena version (default: latest)
```

## Installing with Docker Machine

> Prerequisities: You'll need [Docker Machine](https://docs.docker.com/machine/) installed on your system.

It is possible to provision Kontena Nodes with Docker Machine. The only issue with Docker Machine provisioning is that it requires manual DNS configuration for each host.

### Provision a Docker Machine

You can use Docker Machine to provision a machine to the (cloud) platform of your choice. See Docker Machine documentation for details. In the example below, we'll provision a `virtualbox` machine.

```
$ docker-machine create --driver virtualbox kontena-node-1
```

### Start Kontena Agent

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
    -e KONTENA_URI=<uri> \
    -e KONTENA_TOKEN=<token> \
    -e KONTENA_PEER_INTERFACE=eth1 \
    -v=/var/run/docker.sock:/var/run/docker.sock \
    --net=host \
    kontena/agent:latest
```

### Verify Installation

Once the Kontena Agent has been started, verify the node is correctly registered to Kontena Master.

```
$ kontena node list
```

### Configure DNS (optional)

If you want to use [Kontena Image Registry](../../using-kontena/image-registry.md), you must tweak DNS settings of the machine so that `docker0` ip is preferred name server.


## Manual Install

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

### CoreOS

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

### Ubuntu 14.04

> Prerequisities: Docker 1.7 or later

#### Install Kontena Ubuntu packages

```sh
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-agent
```

#### Configure agents during installation process

* The address of the Kontena server. Note! You must use WebSocket protocol: ws or wss for secured connections
* Grid token from the Kontena server

#### Restart Docker

```sh
$ sudo restart docker
```

#### Verify that agents are connected to server

```sh
$ kontena node list
```
