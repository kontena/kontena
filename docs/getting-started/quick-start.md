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

After the installation is complete, you can test the installation by checking the Kontena CLI version `kontena -v`.

**OPTIONAL**

To enable tab-completion for bash, add this to your `.bashrc` scripts:

```
$ which kontena > /dev/null && . "$( kontena whoami --bash-completion-path )"
```

## Step 2. Register Personal User Account

With Kontena, all users are required to have personal user account. Kontena is using user accounts to enforce access control and to generate audit trail logs form user actions. Create your own personal user account (if not created already).

```
$ kontena register
```

By default, user authentication is made against Kontena's public authentication service. It is also possible for you to host your own authentication service. In this case, the registration is optional.

## Step 3. Install Kontena Master

In order to use Kontena, you'll need Kontena Master. If you don't have existing Kontena infrastructure in place, you'll need to install your own. Kontena Master may be provisioned to any cloud platform. It is also possible to run Kontena Master on your own local development environment for testing purposes.

The easiest (and preferred) way to provision Kontena Master is to use the built-in Kontena Master provision feature of Kontena CLI. In this guide, we will provision Kontena Master to local development environment using [Vagrant](https://www.vagrantup.com/). If you want to install Kontena Master to some other environment, please see [Installing Kontena Master](installing/master.md) documentation.

Since we will be using Vagrant, please ensure you have Vagrant installed. For more details, see official [Vagrant installation docs](https://docs.vagrantup.com/v2/installation/index.html).

```
$ kontena master vagrant create
Creating Vagrant machine kontena-master-autumn-waterfall-70 ... done
Waiting for kontena-master-autumn-waterfall-70 to start ... done
Kontena Master is now running at http://192.168.66.100:8080
Use kontena login http://192.168.66.100:8080 to complete Kontena Master setup
```

## Step 4. Login and Create a Grid

Before we can provision Kontena Nodes, we need to login to Kontena Master and create a Kontena Grid. Login with your personal user account. For example, if the Kontena Master is running at address `http://192.168.66.100:8080`, the login is done like this:

```
$ kontena login http://192.168.66.100:8080
Email: your.email@domain.com
Password: *********
 _               _
| | _ ___  _ __ | |_ ___ _ __   __ _
| |/ / _ \| '_ \| __/ _ \ '_ \ / _` |
|   < (_) | | | | ||  __/ | | | (_| |
|_|\_\___/|_| |_|\__\___|_| |_|\__,_|
-------------------------------------
Copyright (c)2015 Kontena, Inc.

Logged in as your.email@domain.com
Welcome! See 'kontena --help' to get started.
```

Once logged in, you'll need to create a Grid that will be used in the next step when installing Kontena Nodes. The Grid can be created with command `kontena grid create`. For example, to create a grid named `mygrid`:

```
$ kontena grid create testing
```

## Step 5. Install Kontena Nodes

You'll need some Kontena Nodes to run your containerized workloads. If you don't have existing Kontena infrastructure in place, you'll need to install your own.

Just like with Kontena Master, the easiest (and preferred) way to provision Kontena Nodes is to use the built-in Kontena Node provision feature of Kontena CLI. In this guide, we will provision Kontena Nodes to local development environment using [Vagrant](https://www.vagrantup.com/). If you want to install Kontena Nodes to some other environment, please see [Installing Kontena Nodes](installing/nodes.md) documentation.

Since we will be using Vagrant, please ensure you have Vagrant installed. For more details, see official [Vagrant installation docs](https://docs.vagrantup.com/v2/installation/index.html).

```
$ kontena node vagrant create
Creating Vagrant machine kontena-node-broken-butterfly-72... done
Waiting for node kontena-node-broken-butterfly-72 join to grid testing... done
```

You can repeat this step to provision additional Kontena Nodes to your Grid.

**Note!** While Kontena works ok even with just single Kontena Node, it is recommended to have at least 2 Kontena Nodes provisioned in a Grid.

## Congratulations, Enjoy!

If you followed the steps above, you should now have a working Kontena setup installed. Verify the setup using `kontena node list` command. It should list all the Kontena Nodes in your Grid.

```
$ kontena node list
```

This completes the quick start guide for setting up Kontena. Learn more about the [architecture](../core-concepts/architecture.md) and usage of Kontena. We hope you will find this documentation helpful! If you have any suggestions how to improve our documentation, please [open an issue](https://github.com/kontena/kontena/issues) at GitHub.
