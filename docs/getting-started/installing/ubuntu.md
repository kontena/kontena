---
title: Ubuntu
---

# Running Kontena on Ubuntu

- [Prerequisites](ubuntu.md#prerequisites)
- [Installing Kontena Master](ubuntu.md#installing-kontena-master)
- [Installing Kontena Nodes](ubuntu.md#installing-kontena-nodes)

## Prerequisites

- [Kontena CLI](cli.md)

## Installing Docker Engine

Kontena requires [Docker Engine](https://docs.docker.com/engine/) to be installed on every host (Master and Nodes).

The `kontena-server` and `kontena-agent` packages are compatible with Docker 1.12 and later versions. They have been tested with the following package variants and versions:

* `docker.io` `1.12.6`
* `docker-engine` `1.12.6` - `17.05.0`
* `docker-ce` `1.12.6` - `17.06.0`

#### Ubuntu Xenial (16.04)

```
$ sudo apt install docker.io=1.12*
```

#### Ubuntu Trusty (14.04)

```
$ sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
$ echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" | sudo tee -a /etc/apt/sources.list.d/docker.list
$ sudo apt-get update
$ sudo apt-get install apt-transport-https ca-certificates linux-image-extra-$(uname -r) linux-image-extra-virtual
$ sudo apt-get install docker-engine=1.12.*
```

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master to Ubuntu can be accomplished by installing the kontena-server package using the appropriate commmands for your version of Ubuntu:


#### Ubuntu Xenial (16.04)

```
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/ubuntu xenial main" | sudo tee /etc/apt/sources.list.d/kontena.list
$ sudo apt-get update
$ sudo apt-get install kontena-server
```

#### Ubuntu Trusty (14.04)

```
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/ubuntu trusty main" | sudo tee /etc/apt/sources.list.d/kontena.list
$ sudo apt-get update
$ sudo apt-get install kontena-server
```

At the end of the installation process, you are asked for an initial admin code for the Kontena Master. This is used to authenticate the initial admin connection of Kontena CLI in order to configure the Kontena Master properly. The code can be any random string.

If using automation the value can be overwritten in the file `/etc/default/kontena-server-api` on Ubuntu Trusty or `/etc/kontena-server.env` on Ubuntu Xenial.

### Setup SSL Certificate


#### Ubuntu Xenial (16.04)

```
$ sudo vim /etc/kontena-server.env

# HAProxy SSL certificate
SSL_CERT=/path/to/certificate.pem

$ sudo systemctl restart kontena-server-haproxy
```

#### Ubuntu Trusty (14.04)

```
$ sudo stop kontena-server-haproxy
$ sudo vim /etc/default/kontena-server-haproxy

# HAProxy SSL certificate
SSL_CERT=/path/to/certificate.pem

$ sudo start kontena-server-haproxy
```


### Login to Kontena Master


After Kontena Master has started you can authenticate as the Kontena Master internal administrator using the `INITIAL_ADMIN_CODE` you provided. Refer to [authentication](../../using-kontena/authentication.md) for instructions on configuring [Kontena Cloud](https://cloud.kontena.io) as the authentication provider.

```
kontena master login --name some-name --code <admin code> https://master_ip:8443
```

## Installing Kontena Nodes

Before you can start provisioning Nodes you must first switch the CLI scope to a Grid. A Grid can be thought as a cluster of Nodes that can have members from multiple clouds and/or regions.

Switch to an existing Grid using the following command:

```
$ kontena grid use <grid_name>
```

Or create a new Grid using the command:

```
$ kontena grid create test-grid
```

Remember to grab the token for the Grid, you'll need it when setting up Node(s).

```
$ kontena grid show --token test-grid
```

Now you can go ahead and install the `kontena-agent` Ubuntu package using the appropriate commands for your Ubuntu version:

#### Ubuntu Xenial (16.04)

```
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/ubuntu xenial main" | sudo tee /etc/apt/sources.list.d/kontena.list
$ sudo apt-get update
$ sudo apt-get install kontena-agent
```

#### Ubuntu Trusty (14.04)

```
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/ubuntu trusty main" | sudo tee /etc/apt/sources.list.d/kontena.list
$ sudo apt-get update
$ sudo apt-get install kontena-agent
```

At the end of the installation the process, you will be asked for a couple of configuration parameters:

* The address of the Kontena Master. **Note:** You must use WebSocket protocol: ws or wss for secured connections
* The Grid token from the Kontena Master

After installing all the Kontena Agents, you can verify that they have joined a Kontena Grid using the command:

```
$ kontena node list
```
