---
title: Etcd
---

# Etcd

Etcd is a distributed key-value store for shared configuration and service discovery. Each Kontena [Grid](grid) comes with etcd preinstalled and available on the `etcd.kontena.local` address. The Kontena CLI provides some helper commands to interact with etcd. In addition to these it is possible to interact with etcd using the normal etcdctl interface or via the HTTP API through [VPN](vpn-access.md).

## Set a value

```
$ kontena etcd set <path> <value>
```

## Get a value

```
$ kontena etcd get <path>
```

## Make a directory

```
$ kontena etcd mk <path>
```

## List a directory

```
$ kontena etcd ls <path>
```

## Remove a key

```
$ kontena rm <path_to_key>
```

# Remove a directory

```
$ kontena rm --recursive <path_to_directory>
```
