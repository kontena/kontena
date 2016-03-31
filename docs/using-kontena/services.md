---
title: Services
toc_order: 3
---

# Services

A [Service](../core-concepts/architecture.md#services) is composed of Containers based on the same image file.

* [Service Discovery](./#service-discovery)
* [High Availability](./#service-high-availability)
* [Using Services](./#using-services)

## Service Discovery

Each service instance is automatically registered in Kontena Grid distributed DNS service, which makes them discoverable through simple name lookups. For example: if service is named as `nginx` and it has been scaled to two instances, then first instance can be found via `nginx-1.<grid>.kontena.local` dns address, second via `nginx-2.<grid>.kontena.local` etc. It's also possible to query service dns that returns all service instances records. For example, `nginx.<grid>.kontena.local` dns address will return both `nginx-1` and `nginx-2` instance addresses in random order.

## Service High Availability

Kontena monitors the state of each service instance and actively manages to ensure the desired state of the service. This can be triggered when there are fewer healthy instances than the desired scale of your service, a node becomes unavailable or a service instance fails.

## Using Services

### Create a New Service

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

### Deploy Service

```
$ kontena service deploy nginx
```

To see all available options, see help:

```
$ kontena service deploy --help
```

### Update Service

```
$ kontena service update --environment FOO=BAR nginx
```

Note: `kontena service update` command does not deploy service. It must be done separately with `kontena service deploy`.

### Scale Service

```
$ kontena service scale nginx 4
```

### Show Service Details

```
$ kontena service show nginx
```

### Show Service Logs

```
$ kontena service logs nginx
```

### Show Service Statistics

```
$ kontena service stats nginx
```

### Monitor Service Instances

```
$ kontena service monitor nginx
```
