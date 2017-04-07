---
title: Volume Management
---

# Volumes

Kontena 1.2 provides **experimental** support for managing persistent service data using Docker volumes. The exact details of how these Kontena volumes are managed may still change as the implementation evolves. If you use the experimental Kontena volumes support, be prepared to change your volume definitions as necessary when upgrading to newer Kontena versions.


Volumes are supported as first-class objects in the Kontena Master API, which can be referred to from stack YAML definitions.

Kontena tracks the available Docker volume drivers on each host node, as shown in `kontena node show`, and will only deploy services using such a volume driver onto a host node that provides that volume driver. In order to use any other volume drivers than the default local driver, those volume drivers must be provided by Docker plugins on the host nodes. Kontena itself does not yet support provisioning Docker plugins onto the grid's host nodes.

A given Kontena volume can be used by multiple Kontena service instances deployed to different host nodes, and the Kontena scheduler will automatically create multiple separate volume instances for each Kontena volume. These volume instances correspond to a specific Docker volume on a specific host node. The scheduling behavior of each Kontena volume depends on the volume's scope, and any pre-existing volume instances.


## Managing volumes with CLI

Volumes can be managed from the Kontena CLI using the `kontena volume xyz` commands.

### Creating volumes

`kontena volume create --driver rexray --scope instance my-volume`

See volume [scopes](#volume-scopes) for details on the different scopes.

### Listing volumes

```
$ kontena volume ls

NAME                      SCOPE                     DRIVER                    CREATED AT               
redis-data                grid                      local                     2017-04-06T06:57:34.374Z
test-s3fs                 grid                      rexray/s3fs               2017-04-05T13:06:26.252Z
```

### Getting volume details

```
$ kontena volume show my-volume

$ kontena volume show foo
foo:
  id: test/foo
  created: 2017-04-05T22:11:34.201Z
  scope: instance
  driver: local
  driver_opts:
  instances:
    - name: redis.foo-2
      node: moby
    - name: redis.foo-1
      node: moby
  services:
    - test/null/redis
```


### Deleting volumes

`kontena volume rm my-volume`

Deleting a volume that is still in use by any Kontena services will fail. Deleting an unused volume will remove the underlying Docker volumes from the host nodes.

**NOTE:**
Depending on the volume driver used this may actually also remove the backing storage for the volume.

## Using volumes with Kontena Stacks

Volumes can be used by services defined in Kontena stacks. To be able to use a volume in a service the volume must be first created using `kontena volume create ...` command or the corresponding REST API on Kontena master and introduced in stack yaml in a top level `volumes` section.


Volumes configuration looks like this in stack yaml:
```
stack: redis
description: Just a simple Redis stack with volume for persistent data
version: 0.0.1
services:
  redis:
    image: redis:3.2-alpine
    stateful: true
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data

volumes:
  redis-data:
    external:
      name: redis-volume
```

See stack yaml reference for details.

## Volume scopes

Volume scopes define how the volumes will be "instantiated" when they are used in services.

Valid scopes are: `instance`, `stack` or `grid`.

The suitable scope depends highly on the service using the data and the volume driver providing the actual data persistence.

### Scope: instance

Instance scoped volumes are created per service instance so in practice each service instance (container) will get it's own volume.

Kontena will always prefer to schedule a service using a `scope: instance` volume onto the same host node that the volume was originally created on. If that host node is unavailable, a new volume instance will be created on a different node.

Suitable for services where each instance should have their own data and possible data replication happens on application layer.

### Scope: stack

Stack scoped volumes are created once per stack per node. This means that services within the same stack and running on same node will use the same Docker volume. A service using a `scope: stack` volume may be scheduled onto any host node, as limited by the service's affinity filters and available volume drivers on each node.

Suitable for services which need to share the same data between different instances and the volume driver takes care of the data replication between volumes created on different nodes.

### Scope: grid

Grid scoped volumes are created once per grid per node. A `scope: grid` volume can be used to import existing Docker volumes, as Kontena will use the exact volume name for the Docker volume. A service using a `scope: grid` volume may be scheduled onto any host node, as limited by the service's affinity filters and available volume drivers on each node.

Suitable for services and stacks which need to share the same data between different services/stacks and the volume driver takes care of the data replication between volumes created on different nodes.
