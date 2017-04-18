---
title: MariaDB Galera Cluster
---

# MariaDB Galera Cluster on Kontena

> Prerequisites: You need to have working [Kontena](http://www.kontena.io) Container Platform installed. If you are new to Kontena, check [quick start guide](http://www.kontena.io/docs/getting-started/quick-start).   

![mariadb logo](https://upload.wikimedia.org/wikipedia/en/3/3e/MariaDB_Logo_from_SkySQL_Ab.png)

## Deploy

**Step 1:** download [kontena.yml](kontena.yml)

**Step 2:** write secrets to [Kontena Vault](http://www.kontena.io/docs/using-kontena/vault):

```
$ kontena vault write GALERA_XTRABACKUP_PASSWORD "top_secret"
$ kontena vault write GALERA_MYSQL_ROOT_PASSWORD "top_secret"
```

**Step 3:** deploy the stack:

```
$ kontena app deploy
```

Command deploys 1 x MariaDB Galera seed node, 3 x normal nodes and 2 x haproxy load balancers.

**Step 4:** after cluster is bootstrapped seed node should be removed:

```
$ kontena app scale seed 0
```

## Accessing Cluster

MariaDB Galera Cluster load balancer can be accessed via `mariadb-galera-lb.kontena.local` dns-address from other services or via [Kontena VPN](http://www.kontena.io/docs/using-kontena/vpn-access).
