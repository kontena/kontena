# Installing Kontena to a Single Ubuntu Server

This guide will install Kontena Server & Agent to a single Ubuntu host. It does not setup overlay networking so it's only recommended for testing purposes.

> Prerequisities: Docker 1.4 or later

### Install Kontena Server Ubuntu Packages

```sh
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-server
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
$ kontena register # if you don't have Kontena account
$ kontena login
$ kontena grid create first-grid
$ kontena grid show first-grid
first-grid:
  token: <grid_token>
  users: 1
  nodes: 0
  containers: 0

```

### Install and Configure Agent
$ sudo apt-get install kontena-agent

#### Configure agents during installation process
* the address of the Kontena server: ws://localhost:8080
* grid token: <grid_token_from_server>
* node number: 1
* addresses of other nodes: empty

### Restart Docker

```
$ sudo restart docker
```

### Deploy First Service

```sh
$ kontena service create ghost-blog ghost:0.5 --stateful -p 8181:2368
$ kontena service deploy
```

Now open browser at http://localhost:8181
