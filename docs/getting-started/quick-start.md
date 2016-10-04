---
title: Quick Start
toc_order: 1
---

# Quick Start

Follow these steps to get started with Kontena quickly.

## Step 1. Install Kontena CLI (command-line interface)

> Prerequisities: You'll need Ruby version 2.0 or later installed on your system. For more details, see official [Ruby installation docs](https://www.ruby-lang.org/en/documentation/installation/).

You can install the Kontena CLI with Rubygems package manager (included in Ruby).

```
$ gem install kontena-cli
```

After the installation is complete, you can test the installation by checking the Kontena CLI version `kontena version`.

**OPTIONAL**

To enable tab-completion for bash, add this to your `.bashrc` scripts:

```
which kontena > /dev/null && . "$( kontena whoami --bash-completion-path )"
```

## Step 2. Register Personal User Account

With Kontena, all users are required to have a personal user account. Kontena is using user accounts to enforce access control and to generate audit trail logs from user actions. Create your own personal user account (if not created already). You can register an account at [Kontena Cloud](https://cloud.kontena.io/).

By default, user authentication is made against Kontena's public authentication service. It is also possible for you to host your own authentication service or use a 3rd party oauth2 provider.

You can read more about the authentication and configuring authentication providers in the [Authentication](../using-kontena/authentication.md) documentation.

To authenticate your CLI to Kontena Cloud use the command:

```
$ kontena cloud login
```

## Step 3. Install Kontena Master

In order to use Kontena, you'll need Kontena Master. If you don't have existing Kontena infrastructure in place, you'll need to install your own. Kontena Master may be provisioned to any cloud platform. It is also possible to run Kontena Master on your own local development environment for testing purposes.

The easiest (and preferred) way to provision Kontena Master is to use the built-in Kontena Master provision feature of Kontena CLI. In this guide, we will provision Kontena Master to local development environment using [Vagrant](https://www.vagrantup.com/). If you want to install Kontena Master to some other environment, please see [Installing Kontena](installing/) documentation.

Since we will be using Vagrant, please ensure you have Vagrant 1.6 or later installed. For more details, see official [Vagrant installation docs](https://docs.vagrantup.com/v2/installation/index.html).

```
$ kontena plugin install vagrant
$ kontena vagrant master create

## Step 4. Login and Create a Grid

Before we can provision Kontena Nodes, you need to be authenticated to Kontena Master. The Master installation will do this automatically for you. Here is how you do it manually:

```
$ kontena master login http://192.168.66.100:8080
```

Once logged in, you'll need to create a Grid that will be used in the next step when installing Kontena Nodes. A Grid called 'test' will be automatically created during Master installation. A new Grid can be created with command `kontena grid create`. For example, to create a grid named `testing`:

```
$ kontena grid create testing
```

## Step 5. Install Kontena Nodes

You'll need some Kontena Nodes to run your containerized workloads. If you don't have existing Kontena infrastructure in place, you'll need to install your own.

Just like with Kontena Master, the easiest (and preferred) way to provision Kontena Nodes is to use the built-in Kontena Node provision feature of Kontena CLI. In this guide, we will provision Kontena Nodes to local development environment using [Vagrant](https://www.vagrantup.com/). If you want to install Kontena Nodes to some other environment, please see [Installing Kontena Nodes](installing/nodes.md) documentation.

Since we will be using Vagrant, please ensure you have Vagrant installed. For more details, see official [Vagrant installation docs](https://docs.vagrantup.com/v2/installation/index.html).

```
$ kontena vagrant node create
Creating Vagrant machine kontena-node-broken-butterfly-72... done
Waiting for node kontena-node-broken-butterfly-72 join to grid testing... done
```

You can repeat this step to provision additional Kontena Nodes to your Grid.

**Note!** While Kontena works ok even with just a single Kontena Node, it is recommended to have at least 2 Kontena Nodes provisioned in a Grid.

If you followed the steps above, you should now have a working Kontena setup installed. Verify the setup using `kontena node list` command. It should list all the Kontena Nodes in your Grid.

```
$ kontena node list
```

## Step 6. Deploy Your First Application

 Now you are ready to deploy your first application. In this section we will show you how to deploy a simple Wordpress application and deploy it to your Kontena grid.

First create `kontena.yml` file with the following contents:

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

After the deploy is finished you can verify it using:

```
$ kontena app show wordpress
```

It should show details of the service. If you view the node details (`$ kontena node show <node>`), you can pick the private IP address of the node and verify in a browser that application is responding.
**Note:** This is only the special case for the Vagrant setup, normally you can just pick the public IP of the service from the application details.

If you need more complex examples, please see the following examples:

- [Wordpress Cluster](https://github.com/kontena/examples/tree/master/wordpress-cluster)
- [Jenkins](https://github.com/kontena/examples/tree/master/jenkins)
- [MongoDB Cluster](https://github.com/kontena/examples/tree/master/mongodb-cluster)


## Congratulations, Enjoy!

This completes the quick start guide for setting up Kontena. You can now continue to learn more about:

 - [Kontena Architecture](../core-concepts/architecture.md)
 - [Using Kontena](../using-kontena/)

We hope you will find this documentation helpful! If you have any suggestions how to improve our documentation, please [open an issue](https://github.com/kontena/kontena/issues) at GitHub.
