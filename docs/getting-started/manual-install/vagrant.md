---
title: Vagrant
toc_order: 5
---

# Running Kontena with Vagrant

The easiest way to give [Kontena](http://www.kontena.io) a test run is to run it on your local machine

> Prerequisities: [Vagrant](https://www.vagrantup.com/)

## Install Kontena Environment

###Download Vagrantfile
[Vagrantfile](https://github.com/kontena/kontena/blob/master/docs/getting-started/manual-install/Vagrantfile)

### Deploy Kontena Server and Agents
Run the following command in the same directory where you have saved the Vagrantfile
```sh
$ EMAIL='your_email_address' vagrant up
```
NOTE: It takes 5-10 minutes to get environments up and running

##Install Kontena CLI
```sh
$ gem install kontena-cli
```

##Usage
###Register Kontena account, if you don't have account yet
```sh
$ kontena register
```
Use the same email address as in `vagrant up` command

###Login to Kontena server
```sh
$ kontena login http://192.168.66.100:8080
```
###Use Kontena
```sh
$ kontena grid list
$ kontena grid use demo
```
To see all commands:
```sh
$ kontena help
```

### Deploy First Service

```sh
$ kontena service create ghost-blog ghost:0.5 --stateful -p 8181:2368
$ kontena service deploy ghost-blog
```

Now open browser at http://192.168.66.2:8181

