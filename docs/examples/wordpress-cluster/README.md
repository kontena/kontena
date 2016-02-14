---
title: Wordpress Cluster
---

# Wordpress Cluster with Kontena Deploy

Building clustered Wordpress environment with [Kontena](http://www.kontena.io).

[![kontena diagram](http://image.slidesharecdn.com/kontenadockermeetuppdf-150327023059-conversion-gate01/95/building-high-availability-application-with-docker-1-638.jpg?cb=1427426338)](http://www.slideshare.net/nevalla/building-high-availability-application-with-docker)

## Deploy

**Step 1:** download [kontena.yml](kontena.yml)

**Step 2:** write btsync secret to Kontena Vault

Database secrets:

```
$ kontena vault write XTRABACKUP_PASSWORD "supersecret"
$ kontena vault write MYSQL_ROOT_PASSWORD "supersecret"
$ kontena vault write WORDPRESS_DB_PASSWORD "supersecret"
```

Btsync secret:
```
$ kontena vault write WORDPRESS_BTSYNC_SECRET "$(docker run -i --rm --entrypoint=/usr/bin/btsync jakolehm/btsync:latest --generate-secret)"
```

**Step 3:** deploy Wordpress cluster

```
$ kontena app deploy
```
