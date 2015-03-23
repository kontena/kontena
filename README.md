# Kontena Agent

[![Build Status](https://travis-ci.org/kontena/kontena-agent.svg?branch=master)](https://travis-ci.org/kontena/kontena-agent)

Kontena is a tool for monitoring and managing containerized services and applications. Kontena Agent runs inside a Docker container and communicates to Kontena Server using WebSockets. Agent handles containers inside a single host node and accepts commands from Kontena Server.

## Features

* Realtime control channel to Kontena server
* Reporting to Kontena server
  * Containers
  * Logs
  * Metrics (collected from [cAdvisor](https://github.com/google/cadvisor))
  * Events
* Dns-server for service discovery
* Cross-node networking (powered by [Weave](https://github.com/zettio/weave))

## Installation

> Prerequisities: Docker 1.4 or later

### Ubuntu 14.04

```sh
echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get install kontena-agent
```

## Configure

#### Stop docker
```sh
$ sudo stop docker
```

#### Modify Docker network config
```sh
$ sudo vim /etc/default/docker
DOCKER_OPTS="--bridge=weave --fixed-cidr=10.81.1.0/24 --dns 8.8.8.8 --dns 8.8.4.4"
```
> Note: each docker node must have different 10.81.x.0/24 subnet

#### Modify Kontena Agent config:
```sh
$ sudo vim /etc/default/kontena-agent

# Set to your kontena server
KONTENA_URI=wss://kontena.mydomain.com:8443

# Set kontena grid token
KONTENA_TOKEN=<grid_token_from_server>

```

#### Modify Weave config:
```sh
$ sudo vim /etc/default/kontena-weave

# Set Weave peer nodes
WEAVE_PEERS=<ips_of_other_peers>
```

#### Modify Weave network config:
```sh
$ sudo vim /etc/network/interfaces.d/kontena-weave.cfg

post-up ip addr add dev weave 10.81.0.1/16
```
> Note: each docker node must have different 10.81.0.x/16 cidr

#### Start Docker:
```sh
$ sudo start docker
```

## Development

Set development env variables to .env file:

```
KONTENA_URI=ws://kontena.local:4040
KONTENA_TOKEN=secret_grid_token
AGENT_NAME=vagrant_agent_1
```

Start agent using Docker Compose:

```sh
$ docker-compose up
```

Run specs:

```sh
$ rspec spec/
```

Build:

```sh
$ docker build -t kontena/agent .
```

## License

Kontena is licensed under the Apache License, Version 2.0. See [LICENCE](LICENSE) for full license text.
