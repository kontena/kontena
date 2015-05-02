# Kontena installation to multiple Ubuntu nodes

This guide describes how to install Kontena on multiple Ubuntu nodes, including 1 server node and 3 agent nodes. This approach can scale to **any number of agent nodes** with ease.

> Prerequisities: Docker 1.4 or later

Example cluster setup:

| IP Address | Overlay IP | Role   |
| ---------- | ---------- | ------ |
| 10.2.2.99  | -          | server |
| 10.2.2.101 | 10.81.0.1  | agent  |
| 10.2.2.102 | 10.81.0.2  | agent  |
| 10.2.2.103 | 10.81.0.3  | agent  |

## Install server

### Install Kontena Ubuntu packages

```sh
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-server
```

### Setup ssl certificate (optional)

```sh
$ sudo vim /etc/default/kontena-server-haproxy

# HAProxy SSL certificate
SSL_CERT=/path/to/certificate.pem
```

### Start Kontena server

```
$ sudo start kontena-server-api
```

### Install Kontena cli

```sh
$ gem install kontena-cli
```

### Connect & configure first grid

```
$ kontena connect http://10.2.2.99:8080 # use https and 8443 port if you configured ssl certificate
$ kontena register # if you do not have Kontena account
$ kontena login
$ kontena grid create first-grid
$ kontena grid use first-grid
$ kontena grid current
first-grid:
  token: <grid_token>
  users: 1
  nodes: 0
  containers: 0

```

## Install agents

Do the following configuration on each agent node.

### Install Kontena Ubuntu packages

```sh
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-agent
```

### Stop Docker

```sh
$ sudo stop docker
```


### Configure Agent

```sh
$ sudo vim /etc/default/kontena-agent

# Set to your kontena server (use wss and 8443 port if you have ssl setup)
KONTENA_URI=ws://10.2.2.99:8080

# Set kontena grid token
KONTENA_TOKEN=<grid_token_from_server>
```

### Configure networking overlay


#### Modify Docker config
```sh
$ sudo vim /etc/default/docker
DOCKER_OPTS="--bridge=weave --fixed-cidr=10.81.1.0/24 --dns 8.8.8.8 --dns 8.8.4.4"
```
> Note: each agent node must have different 10.81.x.0/24 subnet

#### Configure Weave overlay network

```sh
$ sudo vim /etc/default/kontena-weave

# Set Weave peer nodes
WEAVE_PEERS="10.2.2.102 10.2.2.103" # ip's of other agent nodes
```
> Note: each agent node must has different weave peers

```sh
$ sudo vim /etc/network/interfaces.d/kontena-weave.cfg

post-up ip addr add dev weave 10.81.0.1/16
```
> Note: each agent node must have different 10.81.0.x/16 cidr

### Start Docker

```sh
$ sudo start docker
```


### Start Agent

```
$ sudo start kontena-cadvisor kontena-agent
```

### Verify that agents are connected to server

```
$ kontena node list
```
