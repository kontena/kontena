---
title: Secrets Management
---

# Kontena Vault

When your application requires access to APIs or databases, you'll often need to use secrets such as passwords and access tokens for authenticating the access. Kontena Vault is a secure key-value storage system that can be used to manage secrets in Kontena. Vault secrets are shared on the Grid level.

A simple way to pass secrets to a Kontena Service is to use environment variables. While you could configure secrets using environment variables in the `kontena.yml` file, this is not recommended. Conceptually, the `kontena.yml` file is a blueprint just like the `Dockerfile` or `docker-compose.yml` that people should be able to share. The proper way to handle secrets is to use Kontena Vault.

## Using Vault

* [List Secrets](vault.md#list-secrets)
* [Write a Secret](vault.md#write-a-secret-to-vault)
* [Read a Secret](vault.md#read-a-secret)
* [Update Secret](vault.md#update-secret)
* [Remove a Secret](vault.md#remove-a-secret)
* [Using Secrets with Stacks](vault.md#using-secrets-with-stacks)


### List Secrets

```
$ kontena vault ls
```

### Write a Secret to Vault

```
$ kontena vault write <name> <value>
```

### Read a Secret

```
$ kontena vault read <name>
```

**Note:** Every read command will be added to the Kontena Master audit log

### Update Secret

```
$ kontena vault update <name> <value>
```

### Remove a Secret

```
$ kontena vault rm <name>
```

### Using Secrets with Stacks

```
services:
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

In the above example, Kontena will read the secret `MYSQL_ADMIN_PASSWORD` from Vault and inject it as an environment variable `MYSQL_PASSWORD` to the Service when it is deployed to Nodes using `kontena stack deploy`.
