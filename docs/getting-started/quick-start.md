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

## Step 2. Register Personal User Account

With Kontena, all users are required to have personal user account. Kontena is using user accounts to enforce access control and to generate audit trail logs form user actions. Create your own personal user account (if not created already).

```
$ kontena register
```

By default, user authentication is made against Kontena's public authentication service. It is also possible for you to host your own authentication service. In this case, the registration is optional.

## Step 3. Install Kontena Master

In order to use Kontena, you'll need Kontena Master. If you don't have existing Kontena infrastructure in place, you'll need to install your own. Kontena Master may be provisioned to any cloud platform. It is also possible to run Kontena Master on your own local development environment for testing purposes.

* [Installing Kontena Master for local testing](installing/master-testing.md) using Vagrant
* [Installing Kontena Master for production](installing/master-production.md)

## Step 4. Login and Create a Grid

Before we can provision Kontena Nodes, we need to login to Kontena Master and create a Kontena Grid. Login with your personal user account. For example, if the Kontena Master is running at address `192.168.66.100` and listening to port `8080`, the login is done like this:

```
$ kontena login http://192.168.66.100:8080
```

Once logged in, you'll need to create a Grid that will be used in the next step when installing Kontena Nodes. The Grid can be created with command `kontena grid create`. For example, to create a grid named `mygrid`:

```
$ kontena grid create mygrid
```

## Step 5. Install Kontena Nodes

You'll need some Kontena Nodes to run your containerized workloads. Just like with Kontena Master, if you don't have existing Kontena infrastructure in place, you'll need to install your own.

The easiest way to provision Kontena Nodes is to use built-in node provision feature of Kontena CLI. Alternatively, you can use [Docker Machine](https://docs.docker.com/machine/) or manual install methods.

* [Installing with Kontena CLI](installing/nodes-cli.md)
* [Installing with Docker Machine](installing/nodes-docker-machine.md)
* [Manual Install](installing/nodes-manual.md)

## Congratulations, Enjoy!

After successful install, you are ready to start using Kontena. Here's some commands to get started:

```
$ kontena service create ghost-blog ghost:0.5 --stateful -p 8181:2368     # create stateful "ghost-blog" service, expose port 8181
$ kontena service deploy ghost-blog                                       # deploy "ghost-blog" service
```

To see all commands:

```
$ kontena help
```

## Next Steps

You are now ready to learn more about the [architecture](../core-concepts/architecture.md) and usage of Kontena. We hope you will find this documentation helpful! If you have any suggestions how to improve our documentation, please [open an issue](https://github.com/kontena/kontena/issues) at GitHub.
