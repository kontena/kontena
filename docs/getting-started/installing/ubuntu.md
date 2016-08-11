---
title: Ubuntu
---

# Running Kontena on Ubuntu

- [Prerequisities](ubuntu#prerequisities)
- [Installing Kontena Master](ubuntu#installing-kontena-master)
- [Installing Kontena Nodes](ubuntu#installing-kontena-nodes)

## Prerequisities

- Kontena Account
- Ubuntu 14.04 with Docker Engine installed

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master to Ubuntu can be done by just installing kontena-server package:

```
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-server
```

### Setup SSL Certificate

```
$ sudo stop kontena-server
$ sudo vim /etc/default/kontena-server-haproxy

# HAProxy SSL certificate
SSL_CERT=/path/to/certificate.pem

$ sudo start kontena-server
```

### Login to Kontena Master

After Kontena Master has installed you can connect to it by issuing login command. First user to login will be given master admin rights.

```
$ kontena login --name ubuntu-master https://<master_ip>/
```

## Installing Kontena Nodes

Before you can start provision nodes you must first switch cli scope to a grid. Grid can be thought as a cluster of nodes that can have members from multiple clouds and/or regions.

Switch to existing grid using following command:

```
$ kontena grid use <grid_name>
```

Or create a new grid using command:

```
$ kontena grid create --initial-size=<initial_size> test-grid
```

Now you can go ahead and install kontena-agent Ubuntu package:

```
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-agent
```

At the end of installation process agent will ask couple of configuration parameters:

* The address of the Kontena master. **Note:** You must use WebSocket protocol: ws or wss for secured connections
* Grid token from the Kontena master

After installing all the agents, you can verify that they have joined Grid:

```
$ kontena node list
```
