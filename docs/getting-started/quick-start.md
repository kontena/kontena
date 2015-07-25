---
title: Quick Start
toc_order: 1
---

# Quick Start

Follow these steps to get started with Kontena quickly.

## Install Kontena CLI (command-line interface)

> Prerequisities: You'll need Ruby version 2.0 or later installed on your system. For more details, see official [Ruby installation docs](https://www.ruby-lang.org/en/documentation/installation/).

You can install the Kontena CLI with Rubygems package manager (included in Ruby).

```
$ gem install kontena-cli
```

After the installation is complete, you can test the installation by checking the Kontena CLI version `kontena -v`.

## Register Personal User Account

With Kontena, all users are required to have personal user account. Kontena is using user accounts to enforce access control and to generate audit trail logs form user actions. Create your own personal user account (if not created already).

```
$ kontena register
```

By default, user authentication is made against Kontena's public authentication service. It is also possible for you to host your own authentication service. In this case, the registration is optional.

## Provision Kontena Infrastructure

If you don't have existing Kontena infrastructure in place, you'll need to provision your own. Choose one of the following providers to provision your infrastructure:

* Amazon AWS
* [Bare Metal (Ubuntu)](manual-install/baremetal-ubuntu.md)
* [Bare Metal (Ubuntu Single Server)](manual-install/baremetal-ubuntu-mini.md)
* [Digital Ocean](manual-install/digital-ocean.md)
* [Vagrant](manual-install/vagrant.md)

## Login

Once you have Kontena infrastructure set-up, you can login to **Kontena Master** with your personal user account.

For example, if the Kontena Master is running at address `192.168.66.100` and listening to port `8080`, the login is done like this:

```
$ kontena login http://192.168.66.100:8080
```

## Enjoy

After successful login, you are ready to start using Kontena. Here's some commands to get started:

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
