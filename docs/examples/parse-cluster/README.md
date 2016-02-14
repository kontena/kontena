---
title: Parse Cluster
---

# Parse Server Cluster on Kontena

A Parse.com API compatible Server Cluster on Kontena

## Deploy

> Prerequisites: You need to have working [Kontena](http://www.kontena.io) Container Platform installed. If you are new to Kontena, check [quick start guide](http://www.kontena.io/docs/getting-started/quick-start).   

Write secrets to [Kontena Vault](http://www.kontena.io/docs/using-kontena/vault):

```
$ kontena vault write PARSE_MASTER_KEY "mySecretMasterKey"
$ kontena vault write PARSE_FILE_KEY "optionalFileKey"
```

Deploy the stack:

```
$ kontena app deploy
```

Command deploys cluster of 3 x MongoDB databases, 3 x parse server and 2 x haproxy load balancer.
