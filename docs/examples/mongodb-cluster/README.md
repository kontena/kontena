---
title: MongoDB Cluster
---

# MongoDB Replica Set Cluster on Kontena

![mongodb logo](https://www.mongodb.com/assets/MongoDB_Brand_Resources/MongoDB-Logo-5c3a7405a85675366beb3a5ec4c032348c390b3f142f5e6dddf1d78e2df5cb5c.png)

## Deploy

> Prerequisites: You need to have working [Kontena](http://www.kontena.io) Container Platform installed. If you are new to Kontena, check [quick start guide](http://www.kontena.io/docs/getting-started/quick-start).   

Deploy the stack:

```
$ kontena app deploy
```

Command deploys 3 x MongoDB instaces and adds instances to Replica Set.

## Accessing MongoDB Replica Set via VPN

MongoDB cluster can be accessed via `mongodb-cluster-peer.kontena.local` dns-address from other services or via [Kontena VPN](http://www.kontena.io/docs/using-kontena/vpn-access).
