---
title: Private Registries
---

# Private Registries

It is possible to use private Docker image registries with Kontena by configuring
registry credentials on Kontena Master. Following are the relevant commands.

### Add Private Registry Configuration

```
$ kontena external-registry add --username <user> --email <email> --password <password> <url>
```

### List Private Registries

```
$ kontena external-registry list
```

### Remove Private Registry Configuration

```
$ kontena external-registry remove <name>
```
