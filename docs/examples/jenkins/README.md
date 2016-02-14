---
title: Jenkins
---

# Jenkins on Kontena

> Prerequisites: You need to have working [Kontena](http://www.kontena.io) Container Platform installed. If you are new to Kontena, check [quick start guide](http://www.kontena.io/docs/getting-started/quick-start).   

![jenkins logo](https://jenkins-ci.org/images/header_logo.png)

## Deploy

**Step 1:** download [kontena.yml](kontena.yml)

**Step 2:** deploy Jenkins master

```
$ kontena app deploy master
```

Jenkins web interface can be accessed through [Kontena VPN](http://www.kontena.io/docs/using-kontena/vpn-access) connection:
http://jenkins-master.kontena.local:8080/

**Step 3:**  deploy Jenkins slave

```
$ kontena app deploy slave
```

Jenkins slave includes docker, docker-compose and kontena cli binaries. It also has access to hosts docker socket.

## Scale

```
$ kontena app scale slave 2
```
