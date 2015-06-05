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
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
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
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-agent
```

#### Configure agents during installation process
* the address of the Kontena server. Note! You must use WebSocket protocol: ws or wss for secured connections
* grid token: <grid_token_from_server>
* node number: 1 for first agent, 2 for second etc.
* addresses of other nodes: ip's of other agent nodes

### Restart Docker

```sh
$ sudo restart docker
```

### Verify that agents are connected to server

```
$ kontena node list
```
