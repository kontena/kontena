---
title: Upgrading
---

# Upgrading Kontena from Previous Versions

Depending on how you installed Kontena, your upgrade steps may vary:

* [Kontena via official plugins](upgrading.md#official-plugins)
* [Kontena via Ubuntu packages](upgrading.md#ubuntu-packages)
* [Kontena via Docker Compose](upgrading.md#docker-compose)


## Upgrading Kontena - Provision Plugins

### Kontena Master

By default plugins will track `latest` version of Kontena and Kontena Master will auto-update when host reboots. This auto-update process can be forced by executing following command in the Kontena Master node:

```
$ sudo systemctl restart kontena-server-api
```

### Kontena Agent

Agents nodes will auto-update to same version as Kontena Master immediately if `major` or `minor` version changes (`major.minor.x`). Agent will do a patch level auto-update only when a node reboots or systemd unit is restarted. This auto-update process can be forced by executing following command in every node:

```
$ sudo systemctl restart kontena-agent
```

## Upgrading Kontena - Ubuntu Packages

Kontena Master & Agent can be updated via `apt-get`:

```
$ sudo apt-get update
$ sudo apt-get upgrade
```

Kontena Master and Agent versions must match at least on `major.major` versions, although it's recommended to keep versions exactly in sync.

## Upgrading Kontena - Docker Compose

Kontena Master & Agent can be updated just by changing image tag and restarting services. Kontena Master and Agent versions must match at least on `major.major` versions, although it's recommended to keep versions exactly in sync.
