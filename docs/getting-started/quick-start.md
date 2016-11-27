---
title: Quick Start
toc_order: 1
---

# Quick Start

Follow these steps to get started with Kontena quickly.

## Step 1. Install Kontena CLI (command-line interface)

> Prerequisites: You'll need Ruby version 2.0 or later installed on your system. For more details, see the official [Ruby installation docs](https://www.ruby-lang.org/en/documentation/installation/).

You can install the Kontena CLI using the Rubygems package manager (which is included in Ruby).

```
$ gem install kontena-cli
```

After the installation is complete, you can test the installation by checking the Kontena CLI version with `kontena version`.

**OPTIONAL**

To enable tab-completion for bash, add this to your `.bashrc` scripts:

```
which kontena > /dev/null && . "$( kontena whoami --bash-completion-path )"
```

## Step 2. Install Kontena Master

In order to use Kontena, you'll need a Kontena Master. If you don't have an existing Kontena infrastructure in place, you need to install one. A Kontena Master can be provisioned for any cloud platform. It' s also possible to run a Kontena Master on your own local development environment for testing purposes.

The easiest (and preferred) way to provision Kontena Master is to use the built-in Kontena Master provision feature of Kontena CLI. In this guide, we will provision Kontena Master to the local development environment using [Vagrant](https://www.vagrantup.com/). If you want to install Kontena Master to some other environment, please see [Installing Kontena](installing/) documentation.

Since we will be using Vagrant, please ensure you have Vagrant 1.6 or later installed. For more details, see the official [Vagrant installation docs](https://docs.vagrantup.com/v2/installation/index.html).

```
$ kontena plugin install vagrant
$ kontena vagrant master create
```

During the installation process you will have the option to select how users will be authenticated with the Kontena Master. It's recommended to select Kontena Cloud as the authentication provider. You can log in or register a new Kontena Cloud account before the Kontena Master installation continues; if you do this, you will be automatically configured to use Kontena Cloud for authentication.

By default, user authentication is made against Kontena's public authentication service. It is also possible for you to host your own authentication service or to use a third-party OAuth2 provider. You can read more about the authentication and configuration of authentication providers in the [Authentication](../using-kontena/authentication.md) documentation.

## Step 3. Install Kontena Nodes

You'll need some Kontena Nodes to run your containerized workloads. If you don't have existing Kontena infrastructure in place, you'll need to install your own.

As with with Kontena Master, the easiest (and preferred) way to provision Kontena Nodes is to use the built-in Kontena Node provisioning feature of Kontena CLI. In this guide, we will provision Kontena Nodes to the local development environment using [Vagrant](https://www.vagrantup.com/). If you want to install Kontena Nodes to some other environment, please see the [Installing Kontena Nodes](installing/nodes.md) documentation.

Since we will be using Vagrant, please ensure you have Vagrant installed. For more details, see official [Vagrant installation docs](https://docs.vagrantup.com/v2/installation/index.html).

Nodes always belong to a Grid. An initial Grid called 'test' has been created during Kontena Master installation. If you want to create or switch to another Grid, you can do it by using:

```
$ kontena grid create testing
# or to switch to an existing grid, use:
$ kontena grid use testing
```

Install a node in the currently selected Grid:

```
$ kontena vagrant node create
Creating Vagrant machine kontena-node-broken-butterfly-72... done
Waiting for node kontena-node-broken-butterfly-72 join to grid test... done
```

You can repeat this step to provision additional Kontena Nodes to your Grid.

**Note!** While Kontena will work with just a single Kontena Node, it is recommended to have at least two Kontena Nodes provisioned in a Grid.

If you followed the steps above, you should now have a working Kontena setup installed. Verify the setup using the `kontena node list` command. It should list all the Kontena Nodes in your Grid.

```
$ kontena node list
```

## Step 4. Deploy Your First Application Stack

 Now you are ready to deploy your first application stack.
 In this section we will show you how to package a simple WordPress application and deploy it to your Kontena Grid.

First create the `kontena.yml` file with the following contents:

```
stack: examples/wordpress
services:
  wordpress:
    image: wordpress:4.1
    stateful: true
    ports:
      - 80:80
    environment:
      - WORDPRESS_DB_HOST=mysql
      - WORDPRESS_DB_USER=root
      - WORDPRESS_DB_PASSWORD=secret
  mysql:
    image: mariadb:5.5
    stateful: true
    environment:
      - MYSQL_ROOT_PASSWORD=secret
```

You can then install and deploy the `wordpress` stack:

```
$ kontena stack install --deploy kontena.yml
 [done] Creating stack wordpress      
 [done] Deploying stack wordpress     
```

The intitial stack deployment may take some time while the host nodes pull the necessary Docker images.

After the stack deployment is finished you can verify that the wordpress and mysql services are running:

```
$ kontena stack show wordpress
wordpress:
  state: running
  created_at: 2016-11-27T10:16:03.080Z
  updated_at: 2016-11-27T10:16:03.080Z
  version: 1
  expose: -
  services:
    wordpress:
      image: wordpress:4.1
      status: running
      revision: 1
      stateful: yes
      scaling: 1
      strategy: ha
      deploy_opts:
        min_health: 0.8
      dns: wordpress.wordpress.development.kontena.local
      ports:
        - 80:80/tcp
    mysql:
      image: mariadb:5.5
      status: running
      revision: 1
      stateful: yes
      scaling: 1
      strategy: ha
      deploy_opts:
        min_health: 0.8
      dns: mysql.wordpress.development.kontena.local
```

This shows the configuration of each deployed stack service.

To test the wordpress service, you must determine the IP address of the host node publishing the wordpress service on TCP port 80:

```
$ kontena service show wordpress/wordpress
development/wordpress/wordpress:
  stack: development/wordpress
  status: running
  image: wordpress:4.1
  revision: 1
  stateful: yes
  scaling: 1
  strategy: ha
  deploy_opts:
    min_health: 0.8
  dns: wordpress.wordpress.development.kontena.local
  env:
    - WORDPRESS_DB_HOST=mysql
    - WORDPRESS_DB_USER=root
    - WORDPRESS_DB_PASSWORD=secret
  net: bridge
  ports:
    - 80:80/tcp
  instances:
    wordpress-wordpress-1:
      rev: 2016-11-27 10:16:03 UTC
      service_rev: 1
      node: core-01
      dns: wordpress-1.wordpress.development.kontena.local
      ip: 10.81.128.30
      public ip: 192.0.2.1
      status: running
      exit code: 0
```

You use the public IP address and published port numbers associated with any service container to access the service. **Note:** For the special case of using Vagrant for the Kontena setup, you must use the *private* IP address of the node running the `wordpress/wordpress` service:

```
$ kontena node show core-01
core-01:
  id: XI4K:NPOL:EQJ4:S4V7:EN3B:DHC5:KZJD:F3U2:PCAN:46EV:IO4A:63S5
  agent version: 1.0.0.pre1
  docker version: 1.11.2
  connected: yes
  last connect: 2016-11-27T08:52:43.776Z
  last seen: 2016-11-27T10:28:59.586Z
  public ip: 192.0.2.1
  private ip: 192.168.66.101
  overlay ip: 10.81.0.1
  os: CoreOS 1185.3.0 (MoreOS)
  driver: overlay
  kernel: 4.7.3-coreos-r2
  initial node: yes
  labels:
  stats:
    cpus: 1
    load: 0.43 0.43 0.37
    memory: 0.7 of 0.97 GB
    filesystem:
      - /var/lib/docker: 4.14 of 15.57 GB
```

For more complex examples of application deployment on Kontena, please see the following examples:

- [WordPress Cluster](https://github.com/kontena/examples/tree/master/wordpress-cluster)
- [Jenkins](https://github.com/kontena/examples/tree/master/jenkins)
- [MongoDB Cluster](https://github.com/kontena/examples/tree/master/mongodb-cluster)

## Congratulations -- Enjoy!

This completes the quick start guide for setting up Kontena. For further learning, you can continue by reading the following:

 - [Kontena Architecture](../core-concepts/architecture.md)
 - [Using Kontena](../using-kontena/)

We hope you will find this documentation helpful! If you have any suggestions on improving our documentation, please [open an issue](https://github.com/kontena/kontena/issues) on GitHub.
