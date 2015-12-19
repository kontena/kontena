---
title: Secrets Management
toc_order: 5
---

# Kontena Vault

When your application requires access to APIs or databases, you'll often need to use secrets such as passwords and access tokens for authenticating the access. Kontena Vault is a secure key/value storage that can be used to manage secrets in Kontena.

A simple way to pass secrets to a Kontena Service is to use environment variables. While you could configure secrets using environment variables in `kontena.yml` file, this is not recommended. Conceptually, the `kontena.yml` file is a blueprint just like `Dockerfile` or `docker-compose.yml` that people should be able to share. Proper way to handle secrets is to use Kontena Vault.

## Using Vault

### Write a Secret to Vault

```
$ kontena vault write <name> <value>
```

### List Secrets

```
$ kontean vault list
```

### Read a Secret

```
$ kontena vault read <name>
```

> Every read command will be added to Kontena Master audit log

### Remove a Secret

```
$ kontean vault rm <name>
```

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

In the above example, Kontena will read secret `MYSQL_ADMIN_PASSWORD` from Vault and inject it as a environment variable `MYSQL_PASSWORD` to service when it is deployed to nodes.
