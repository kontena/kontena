---
title: Secrets Management
toc_order: 5
---

# Kontena Vault

... Introduction ...

## Using Vault

### Write Secret to Vault

```
$ kontena vault write <name> <value>
```

### List Secrets

```
$ kontean vault list
```

### Read Secret

```
$ kontena vault read <name>
```

> Every read command will be audited to Kontena Master audit log

### Using Secrets with Services

```
myapi:
  image: example/myapi:latest
  environment:
    - MYSQL_USER=admin
    - MYSQL_HOST=mysql.kontena.local
  secrets:
    - secret: MYSQL_ADMIN_PASSWORD
      name: MYSQL_PASSWORD
      type: env
```

In this example, Kontena will read secret `MYSQL_ADMIN_PASSWORD` from Vault and inject it as a environment variable `MYSQL_PASSWORD` to service when service is deployed to Nodes.
