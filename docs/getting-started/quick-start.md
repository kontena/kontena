---
title: Quick Start
toc_order: 1
---

# Quick Start

Follow these steps to get started with Kontena quickly.

## Step 1. Install Kontena CLI (command-line interface)

> Prerequisites: You'll need Ruby version 2.1 or later installed on your system. For more details, see the official [Ruby installation docs](https://www.ruby-lang.org/en/documentation/installation/).

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

```yaml
stack: examples/wordpress
version: 0.3.0
variables:
  wordpress-mysql-root:
    type: string
    from:
      vault: wordpress-mysql-root
      random_string: 32
    to:
      vault: wordpress-mysql-root
  wordpress-mysql-password:
    type: string
    from:
      vault: wordpress-mysql-password
      random_string: 32
    to:
      vault: wordpress-mysql-password
services:
  wordpress:
    image: wordpress:4.6
    stateful: true
    ports:
      - 80:80
    environment:
      WORDPRESS_DB_HOST: mysql
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_NAME: wordpress
    secrets:
      - secret: wordpress-mysql-password
        name: WORDPRESS_DB_PASSWORD
        type: env
  mysql:
    image: mariadb:5.5
    stateful: true
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
    secrets:
      - secret: wordpress-mysql-root
        name: MYSQL_ROOT_PASSWORD
        type: env
      - secret: wordpress-mysql-password
        name: MYSQL_PASSWORD
        type: env
```

You can then install and deploy the `wordpress` stack:

```
$ kontena stack install kontena.yml
 [done] Creating stack wordpress
 [done] Deploying stack wordpress
```

The initial stack deployment may take some time while the host nodes pull the referenced Docker images.

After the stack deployment is finished you can verify that the wordpress and mysql services are running:

```
$ kontena stack ls
NAME                                                         VERSION    SERVICES   STATE      EXPOSED PORTS
⊝ wordpress                                                  0.3.0      2          running    *:80->80/tcp
```

You can use the `kontena stack` commands to view the resulting configuration of each deployed stack service:

```
$ kontena service show wordpress/wordpress
test/wordpress/wordpress:
  stack: test/wordpress
  status: running
  image: wordpress:4.6
  revision: 2
  stateful: yes
  scaling: 1
  strategy: ha
  deploy_opts:
    min_health: 0.8
  dns: wordpress.wordpress.test.kontena.local
  secrets:
    - secret: wordpress-mysql-password
      name: WORDPRESS_DB_PASSWORD
      type: env
  env:
    - WORDPRESS_DB_HOST=mysql
    - WORDPRESS_DB_USER=wordpress
    - WORDPRESS_DB_NAME=wordpress
  net: bridge
  ports:
    - 80:80/tcp
  instances:
    wordpress-wordpress-1:
      rev: 2016-11-28 13:51:02 UTC
      service_rev: 2
      node: hidden-moon-99
      dns: wordpress-1.wordpress.test.kontena.local
      ip: 10.81.128.115
      public ip: 192.0.2.1
      status: running
      exit code: 0
```

To test the wordpress service, you must connect to the IP address of the host node publishing the wordpress service on TCP port 80.
You can use the public IP address of the host node running the service instance displayed as part of the `kontena service show` output.
**Note:** For the special case of using Vagrant for the Kontena setup, you must use the *private* IP address of the node running the `wordpress/wordpress` service: `kontena node show hidden-moon-99 | grep 'private ip'`.

For more complex examples of application deployment on Kontena, please see the following examples:

- [WordPress Cluster](https://github.com/kontena/examples/tree/master/wordpress-cluster)
- [Jenkins](https://github.com/kontena/examples/tree/master/jenkins)
- [MongoDB Cluster](https://github.com/kontena/examples/tree/master/mongodb-cluster)

## Congratulations -- Enjoy!

This completes the quick start guide for setting up Kontena. For further learning, you can continue by reading the following:

 - [Kontena Architecture](../core-concepts/architecture.md)
 - [Grids](../using-kontena/grids.md)
 - [Stacks](../using-kontena/stacks.md)
 - [Services](../using-kontena/services.md)
 - [Secrets Management](../using-kontena/vault.md)
 - [Loadbalancer](../using-kontena/loadbalancer.md)

We hope you will find this documentation helpful! If you have any suggestions on improving our documentation, please [open an issue](https://github.com/kontena/kontena/issues) on GitHub.
