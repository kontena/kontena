---
title: Cassandra Cluster
---

# Cassandra on Kontena

![cassandra logo](http://cassandra.apache.org/media/img/cassandra_logo.png)

## Deploy

> Prerequisites: You need to have working [Kontena](http://www.kontena.io) Container Platform installed. If you are new to Kontena, check [quick start guide](http://www.kontena.io/docs/getting-started/quick-start).   

You can deploy Cassandra simply by getting the [kontena.yml](./kontena.yml) file and running command:

```
$ kontena app deploy
```

This will deploy 3 node Cassandra cluster across nodes in your grid. If you need to scale higher,
just change the `instances` variable in `kontena.yml` and redeploy.
