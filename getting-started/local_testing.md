# Testing Kontena Locally
The easiest way to give [Kontena](http://www.kontena.io) a test run is to run it on your local machine

> Prerequisities: [Vagrant](https://www.vagrantup.com/)

## Install Kontena Environment

###Download Vagrantfile
[Vagrantfile](https://gist.github.com/nevalla/3c5d962c99b23f1f2fb2)

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
### Connect CLI to Kontena Server

```sh
$ kontena connect http://192.168.66.100:8080
```
###Register Kontena account
```sh
$ kontena register
```
Use the same email address as `vagrant up`

###Login to Kontena server
```sh
kontena login
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
$ kontena service deploy
```

Now open browser at http://192.168.66.2:8181

