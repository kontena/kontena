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

## Step 4. Deploy Your First Application

 Now you are ready to deploy your first application. In this section we will show you how to initiate a simple WordPress application and deploy it to your Kontena Grid.

First create the `kontena.yml` file with the following contents:

```
version: '2'
services:
  wordpress:
    image: wordpress:4.1
    stateful: true
    ports:
      - 80:80
    links:
      - mysql:wordpress-mysql
    environment:
      - WORDPRESS_DB_HOST=%{project}-mysql.kontena.local
      - WORDPRESS_DB_USER=root
      - WORDPRESS_DB_PASSWORD=secret
  mysql:
    image: mariadb:5.5
    stateful: true
    environment:
      - MYSQL_ROOT_PASSWORD=secret
```

After that you can deploy the application with:

```
$ kontena app deploy
```

After the deployment is finished you can verify it using:

```
$ kontena app show wordpress
```

It should show details of the service. If you view the node details (`$ kontena node show <node>`), you can pick the private IP address of the node and verify in a browser that the application is responding.
**Note:** The private IP address applies only in this special case, where we are using Vagrant for the Kontena setup. Under a normal deployment, you can simply choose the public IP of the service from the application details.

For more complex examples of application deployment on Kontena, please see the following examples:

- [WordPress Cluster](https://github.com/kontena/examples/tree/master/wordpress-cluster)
- [Jenkins](https://github.com/kontena/examples/tree/master/jenkins)
- [MongoDB Cluster](https://github.com/kontena/examples/tree/master/mongodb-cluster)

## Congratulations -- Enjoy!

This completes the quick start guide for setting up Kontena. For further learning, you can continue by reading the following:

 - [Kontena Architecture](../core-concepts/architecture.md)
 - [Using Kontena](../using-kontena/)

We hope you will find this documentation helpful! If you have any suggestions on improving our documentation, please [open an issue](https://github.com/kontena/kontena/issues) on GitHub.
