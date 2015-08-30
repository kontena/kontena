---
title: Upgrading
toc_order: 6
---

# Upgrading Kontena from Previous Versions


## Upgrading from 0.7 to 0.8.0

### Ubuntu

#### Master Server

```
$ sudo apt-get update
$ sudo apt-get install kontena-server=0.8.0-1
```

#### Agent (all nodes)

- remove `--bridge=weave` and `--fixed-cidr="10.81.0.0/16"` from `/etc/default/docker`
- restart docker: `sudo restart docker`
- stop weave: `sudo stop weave-helper && sudo stop weave`
- stop etcd: `sudo stop kontena-etcd`
- upgrade agent: `sudo apt-get update && sudo apt-get install kontena-agent=0.8.0-1`
- restart docker: `sudo restart docker`
- validate that node connects to master (using kontena cli): `kontena node list`
