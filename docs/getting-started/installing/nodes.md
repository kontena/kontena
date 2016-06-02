---
title: Installing Kontena Nodes
toc_order: 2
---

# Installing Kontena Nodes

## Installing with Kontena CLI

Kontena CLI may be used to provision new Kontena Nodes based on [CoreOS](https://coreos.com/using-coreos/), fully configured and ready for action! At the moment, you can provision Nodes to following platforms:

* [Amazon AWS](nodes#amazon-aws)
* [Microsoft Azure](nodes#microsoft-azure)
* [DigitalOcean](nodes#digitalocean)
* [Packet](nodes#packet)
* [Upcloud](nodes#upcloud)
* [Vagrant (local environment)](nodes#vagrant)
* [Docker Machine](nodes#docker-machine)
* [Manual Install](nodes#manual-install)
  * [CoreOS](nodes#coreos)
  * [Ubuntu](nodes#ubuntu-14-04)

We are adding support for other platforms gradually based on your requests. If you'd like to see support for the platform you are using, please [post your request](https://github.com/kontena/kontena/issues) as an issue to our GitHub repository.

### Amazon AWS

```
Usage:
    kontena node aws create [OPTIONS]

Options:
    --grid GRID                   Specify grid to use
    --access-key ACCESS_KEY       AWS access key ID
    --secret-key SECRET_KEY       AWS secret key
    --key-pair KEY_PAIR           EC2 Key Pair
    --region REGION               EC2 Region (default: "eu-west-1")
    --zone ZONE                   EC2 Availability Zone (default: "a")
    --vpc-id VPC ID               Virtual Private Cloud (VPC) ID (default: default vpc)
    --subnet-id SUBNET ID         VPC option to specify subnet to launch instance into (default: first subnet in vpc/az)
    --type SIZE                   Instance type (default: "t2.small")
    --storage STORAGE             Storage size (GiB) (default: "30")
    --version VERSION             Define installed Kontena version (default: "latest")
    --associate-public-ip-address Flag to associate public IP address in VPC that does not do it automatically
    --security-groups             Comma separated list of security group names to which the new master will be attached
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
    --location LOCATION           Location (default: "West Europe")
    --version VERSION             Define installed Kontena version (default: "latest")
```

You can use OpenSSL to create your management certificate. You actually need to create two certificates, one for the server (a .cer file) and one for the client (a .pem file). To create the .pem file, execute this:

```
openssl req -x509 -nodes -days 365 -newkey rsa:1024 -keyout mycert.pem -out mycert.pem
```

To create the .cer certificate, execute this:

```
openssl x509 -inform pem -in mycert.pem -outform der -out mycert.cer
```

For more information about Azure certificates, see [Certificates Overview for Azure Cloud Services](https://azure.microsoft.com/en-us/documentation/articles/cloud-services-certs-create/). For a complete description of OpenSSL parameters, see the documentation at http://www.openssl.org/docs/apps/openssl.html.

After you have created these files, you will need to upload the .cer file to Azure via the "Upload" action of the "Settings" tab of the [Azure classic portal](https://manage.windowsazure.com/), and you will need to make note of where you saved the .pem file.

### DigitalOcean

```
Usage:
    kontena node digitalocean create [OPTIONS]

Options:
    --grid GRID                   Specify grid to use
    --name NAME                   Node name
    --token TOKEN                 DigitalOcean API token
    --ssh-key SSH_KEY             Path to ssh public key
    --size SIZE                   Droplet size (default: "1gb")
    --region REGION               Region (default: "ams2")
    --version VERSION             Define installed Kontena version (default: latest)
```

### Packet

```
Usage:
    kontena node packet create [OPTIONS]

Parameters:
    [NAME]                        Node name

Options:
    --grid GRID                   Specify grid to use
    --token TOKEN                 Packet API token
    --project PROJECT ID          Packet project id
    --type TYPE                   Server type (baremetal_0, baremetal_1, ..) (default: "baremetal_0")
    --facility FACILITY CODE      Facility (default: "ams1")
    --billing BILLING             Billing cycle (default: "hourly")
    --ssh-key PATH                Path to ssh public key (optional)
    --version VERSION             Define installed Kontena version (default: "latest")
```

### Upcloud

```
Usage:
    kontena node upcloud create [OPTIONS] [NAME]

    [NAME]                        Node name

    --grid GRID                   Specify grid to use
    --username USER               Upcloud username
    --password PASS               Upcloud password
    --ssh-key SSH_KEY             Path to ssh public key
    --plan PLAN                   Server size (default: "1xCPU-1GB")
    --zone ZONE                   Zone (default: "fi-hel1")
    --version VERSION             Define installed Kontena version (default: "latest")

Note: The username for ssh access is "root"
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

## Docker Machine

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

Example cloud-config that can be used as a basis for CoreOS installation can be generated via kontena cli:


```
$ kontena grid cloud-config <name>
```

**Options:**

```
--dns DNS                     DNS server
--peer-interface IFACE        Peer (private) network interface (default: "eth1")
--docker-bip BIP              Docker bridge ip (default: "172.17.43.1/16")
--version VERSION             Agent version (default: "latest")
```

### Ubuntu 14.04

> Prerequisities: Docker 1.8 or later

#### Install Kontena Ubuntu packages

```sh
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-agent
```

#### Configure agents during installation process

* The address of the Kontena master. **Note:** You must use WebSocket protocol: ws or wss for secured connections
* Grid token from the Kontena master

#### Restart Docker

```sh
$ sudo restart docker
```

#### Verify that agents are connected to server

```sh
$ kontena node list
```
