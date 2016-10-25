---
title: Etcd
---

# Etcd

Etcd is a distributed key-value store for shared configuration and service
discovery. Each Kontena [Grid](grid) comes with preinstalled etcd that is always available from `etcd.kontena.local` address. Kontena CLI provides some helper commands to interact with etcd. In addition to these it's possible to interact with etcd using normal etcdctl or http api through [VPN](vpn-access).

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

## Remove a key or directory

```
$ kontena rm <path_to_key>
```

```
$ kontena rm --recursive <path_to_directory>
```
