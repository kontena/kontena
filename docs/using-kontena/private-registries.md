---
title: Private Registries
toc_order: 5
---

# Private Registries

## Add external private registry

```
$ kontena external-registry add
Username:
Password:
Email:
URL [https://index.docker.io/v1/]:
```

Just fill in your credentials and external registry address
and you should be able to deploy private images from the added image registry.

## List external private registries

```
$ kontena external-registry list
```

## Remove external private registry

```
$ kontena external-registry delete <NAME>
```
