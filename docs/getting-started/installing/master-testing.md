---
title: Master (testing)
toc_order: 1
---

# Installing Kontena Master for Local Testing

> Prerequisities: You'll need [Vagrant](https://www.vagrantup.com/) installed on your system. For more details, see official [Vagrant installation docs](https://docs.vagrantup.com/v2/installation/index.html).

It is easy to setup Kontena Master for local testing with Vagrant. You'll need to download the [Vagrantfile](Vagrantfile) for Kontena Master setup and run the following command in the same directory where you downloaded the Vagrantfile:

```
$ vagrant up
```

After machine is started, Kontena Master should be available at `http://192.168.66.100:8080` (it might take a minute or two because master needs to pull Docker images from the Docker Hub).
