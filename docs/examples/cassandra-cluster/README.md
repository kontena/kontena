---
title: Cassandra Cluster
---

# Cassandra on Kontena

> Prerequisites: You need to have working [Kontena](http://www.kontena.io) Container Platform installed. If you are new to Kontena, check [quick start guide](http://www.kontena.io/docs/getting-started/quick-start).   

![cassandra logo](http://cassandra.apache.org/media/img/cassandra_logo.png)

## Deploy

**Step 1:** download [kontena.yml](kontena.yml)

**Step 2:** deploy Cassandra

```
$ kontena app deploy
```

This will deploy 3 node Cassandra cluster across nodes in your grid. If you need to scale higher,
just change the `instances` variable in `kontena.yml` and redeploy.
