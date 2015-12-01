---
title: Services
toc_order: 3
---

# Services

A [Service](../core-concepts/architecture.md#services) is composed of Containers based on the same image file.

## Create a New Service

Stateless service:

```
$ kontena service create -p 80:80 nginx nginx:latest
```

Stateful service:

```
$ kontena service create redis redis:latest
```

Note: `kontena service create` command does not deploy service. It must be done separately with `kontena service deploy`.

To see all available options, see help:

```
$ kontena service create --help
```

## Deploy Service

```
$ kontena service deploy nginx
```

To see all available options, see help:

```
$ kontena service deploy --help
```

## Update Service

```
$ kontena service update --environment FOO=BAR nginx
```

Note: `kontena service update` command does not deploy service. It must be done separately with `kontena service deploy`.

## Scale Service

```
$ kontena service scale nginx 4
```

## Show Service Details

```
$ kontena service show nginx
```

## Show Service Logs

```
$ kontena service logs nginx
```

## Show Service Statistics

```
$ kontena service stats nginx
```

## Monitor Service Instances

```
$ kontena service monitor nginx
```
