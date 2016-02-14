---
title: Jenkins
---

# Jenkins on Kontena

![jenkins logo](https://jenkins-ci.org/images/header_logo.png)

## Deploy Jenkins Master

> Prerequisites: You need to have working [Kontena](http://www.kontena.io) Container Platform installed. If you are new to Kontena, check [quick start guide](http://www.kontena.io/docs/getting-started/quick-start).   

```
$ kontena app deploy master
```

Jenkins web interface can be accessed through [Kontena VPN](http://www.kontena.io/docs/using-kontena/vpn-access) connection:
http://jenkins-master.kontena.local:8080/

## Deploy Jenkins Slave

```
$ kontena app deploy slave
```

Jenkins slave includes docker, docker-compose and kontena cli binaries. It also has access to hosts docker socket.

## Scale Jenkins Slaves

```
$ kontena app scale slave 2
```
