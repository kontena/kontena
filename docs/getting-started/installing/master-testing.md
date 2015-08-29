---
title: Master (testing)
toc_order: 1
---

# Installing Kontena Master for Local Testing

Download Kontena Master [Vagrantfile](Vagrantfile) and run the following command in the same directory where you have saved the Vagrantfile:

```
$ vagrant up
```

After machine is started, Kontena Master should be available at http://192.168.66.100:8080 (it might take minute or two because master needs to pull Docker images from the Docker Hub).
