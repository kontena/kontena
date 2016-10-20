---
title: Ubuntu
---

# Running Kontena on Ubuntu

- [Prerequisities](ubuntu#prerequisities)
- [Installing Kontena Master](ubuntu#installing-kontena-master)
- [Installing Kontena Nodes](ubuntu#installing-kontena-nodes)

## Prerequisities

- Kontena Account
- Ubuntu 14.04 or 16.04 with Docker Engine 1.11.x installed

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master to Ubuntu can be done by just installing kontena-server package:

```
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-server
```

At the end of the installation the process master will ask for a initial admin code for the master. This is used to authenticate the initial admin connection of Kontena cli to properly configure the master. The code can be any random string.

If using automation the value can be overwritten in file `/etc/default/kontena-server-api` on Ubuntu Trusty or `/etc/kontena-server.env` on Ubuntu Xenial.

### Setup SSL Certificate

On Ubuntu Trusty

```
$ sudo stop kontena-server-haproxy
$ sudo vim /etc/default/kontena-server-haproxy

# HAProxy SSL certificate
SSL_CERT=/path/to/certificate.pem

$ sudo start kontena-server-haproxy
```

Or on Ubuntu Xenial

```
$ sudo vim /etc/kontena-server.env

# HAProxy SSL certificate
SSL_CERT=/path/to/certificate.pem

$ sudo systemctl restart kontena-server-haproxy
```


### Login to Kontena Master

After Kontena Master has provisioned you will be automatically authenticated as the Kontena Master internal administrator and the default grid 'test' is set as the current grid. Login with the same initial admin code when you setup the master.
```
kontena master login --name some-name --code <admin code> https://master_ip
```

## Installing Kontena Nodes

Before you can start provisioning nodes you must first switch cli scope to a grid. A Grid can be thought as a cluster of nodes that can have members from multiple clouds and/or regions.

Switch to an existing grid using the following command:

```
$ kontena grid use <grid_name>
```

Or create a new grid using the command:

```
$ kontena grid create test-grid
```

Remember to grab the token for the grid, you'll need it when setting up node(s).

```
$ kontena grid show --token test-grid
```

Now you can go ahead and install kontena-agent Ubuntu package:

```
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-agent
```

At the end of the installation the process agent will ask for a couple of configuration parameters:

* The address of the Kontena master. **Note:** You must use WebSocket protocol: ws or wss for secured connections
* The Grid token from the Kontena master

After installing all the agents, you can verify that they have joined a Grid:

```
$ kontena node list
```
