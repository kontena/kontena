---
title: Volume Management
---

# Volumes

Kontena 1.2 provides **experimental** support for managing persistent service data using Docker volumes. The exact details of how these Kontena volumes are managed may still change as the implementation evolves.

Volumes are supported as first-class objects in the Kontena Master API, which can be referred to from stack YAML definitions.

Kontena tracks the available Docker volume drivers on each host node, as shown in kontena node show, and will only deploy services using such a volume driver onto a host node that provides that volume driver. In order to use any other volume drivers than the default local driver, those volume drivers must be provided by Docker plugins on the host nodes. Kontena itself does not yet support provisioning Docker plugins onto the grid's host nodes.


## Managing volumes with CLI

Volumes can be managed from the Kontena CLI using the `kontena volume xyz` commands.

### Creating volumes

`kontena volume create --driver rexray --scope instance my-volume`

See volume [scopes](#volume-scopes) for details on the different scopes.

### Listing volumes

`kontena volume ls`

### Deleting volumes

`kontena volume rm my-volume`

Deleting a volume that is still in use by any Kontena services will fail. Deleting an unused volume will remove the underlying Docker volumes from the host nodes.

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

Suitable for services where each instance should have their own data and possible data replication happens on application layer.

### Scope: stack

Stack scoped volumes are created once per stack per node. This means that services within the same stack and running on same node will use the same Docker volume.

Suitable for services which need to share the same data between different instances and the volume driver takes care of the data replication between volumes created on different nodes.

### Scope: grid

Grid scoped volumes are created once per grid per node.

Suitable for services and stacks which need to share the same data between different services/stacks and the volume driver takes care of the data replication between volumes created on different nodes.
