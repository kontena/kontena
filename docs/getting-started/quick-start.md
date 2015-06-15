# Quick Start

Follow these steps to get started with Kontena quickly.

## Install Kontena CLI (command-line interface)

> Prerequisities: You'll need Ruby version 2.0 or later installed on your system. For more details, see official [Ruby installation docs](https://www.ruby-lang.org/en/documentation/installation/).

You can install the Kontena CLI with Rubygems package manager (included in Ruby).

```sh
$ gem install kontena-cli
```

After the installation is complete, you can test the installation by checking the Kontena CLI version `kontena -v`.

## Provision Kontena Cloud

If you don't have existing Kontena Cloud infrastructure in place, you'll need to provision your own. Choose one of the following providers to provision **Kontena Cloud** infrastructure:

* Amazon AWS
* [Bare Metal (Ubuntu)](deploy-baremetal-ubuntu.md)
* [Bare Metal (Ubuntu Single Server)](deploy-baremetal-ubuntu-mini.md)
* [Digital Ocean](deploy-do.md)
* [Vagrant](deploy-vagrant.md)

## Connect, Register and Login

Once you have Kontena Cloud infrastructure available, you are ready to use Kontena. First, you may create your personal user account (if not created already). The registration is required for all users to enforce access control and to generate audit trail logs.

```sh
$ kontena register
```

Then you can login to Kontena Cloud with your personal account. You'll need the Kontena Master address and port number to log in.

For example, if the Kontena Master is running at address `192.168.66.100` and listening to port `8080`, the login is done like this:

```sh
$ kontena login http://192.168.66.100:8080
```

## Using Kontena

```sh
$ kontena grid list        # list all available Kontena Grids
$ kontena grid use demo    # the name of Kontena Grid you want to use, in this case "demo"
```

To see all commands:

```sh
$ kontena help
```

Deploy your first service:

```sh
$ kontena service create ghost-blog ghost:0.5 --stateful -p 8181:2368
$ kontena service deploy ghost-blog
```

Now open browser at http://192.168.66.2:8181

## Next Steps

You are now ready to learn more about the [core concepts](../core-concepts) and [usage](../using-kontena) of Kontena. We hope you will find this documentation helpful! If you have any suggestions how to improve our documentation, please [open an issue](https://github.com/kontena/kontena/issues) at GitHub.