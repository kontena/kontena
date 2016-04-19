---
title: Private Registries
toc_order: 5
---

# Private Registries

It's possible to use private Docker image registries with Kontena by configuring
registry credentials to Kontena Master.

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
$ kontena external-registry delete <NAME>
```
