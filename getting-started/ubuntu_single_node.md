# Installing Kontena to a Single Ubuntu Server

This guide will install Kontena Server & Agent to a single Ubuntu host. It does not setup overlay networking so it's only recommended for testing purposes.

> Prerequisities: Docker 1.4 or later

### Install Kontena Ubuntu Packages

```sh
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-server kontena-agent
```

### Install Kontena cli

```sh
$ gem install kontena-cli
```

### Start Server

```
$ sudo start kontena-server-api
```

### Connect & Configure First Grid

```
$ kontena connect http://localhost:8080
$ kontena login
$ kontena grid create first-grid
$ kontena grid show first-grid
first-grid:
  token: <grid_token>
  users: 1
  nodes: 0
  containers: 0

```

### Configure Agent

```sh
$ sudo vim /etc/default/kontena-agent

# Set to your kontena server
KONTENA_URI=ws://localhost:8080

# Set kontena grid token
KONTENA_TOKEN=<grid_token_from_server>
```

### Start Agent

```
$ sudo start kontena-cadvisor kontena-agent
```

### Deploy First Service

```sh
$ kontena service create ghost-blog ghost:0.5 --stateful -p 8181:2368
$ kontena service deploy
```

Now open browser at http://localhost:8181
