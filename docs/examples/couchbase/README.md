---
title: Couchbase
---

# Couchbase on Kontena

> Prerequisites: You need to have working [Kontena](http://www.kontena.io) Container Platform installed. If you are new to Kontena, check [quick start guide](http://www.kontena.io/docs/getting-started/quick-start).  

![couchbase logo](https://www.drupal.org/files/project-images/couchbasecicularlogoformarketing.gif)

## Deploy

**Step 1:** download [kontena.yml](kontena.yml)

**Step 2:** deploy Couchbase
```
$ kontena app deploy
```

After deploy has finished, head over to http://couchbase-server-1.kontena.local:8091/ and finish the installation.

## Scale

```
$ kontena app scale 3
```

Adds two more Couchbase server instances to Kontena Grid. After instances are deployed you can add them to CouchBase cluster via web ui. Just use internal DNS names:

- couchbase-server-2.kontena.local
- couchbase-server-3.kontena.local
