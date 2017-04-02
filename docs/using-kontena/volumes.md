---
title: Volume Management
---

# Volumes

Kontena provides capability to manage persistent data using volumes.

Volumes are supported as first-class citizens in both Kontena Master API and on stack yaml definitions.

Currently Kontena does not automatically configure any volume drivers within the grid so user must configure those themselves.


## Managing volumes with CLI

User can manage volumes with Kontena CLI with `kontena volume xyz` commands

### Creating volumes

`kontena volume create --driver rexray --scope instance my-volume`

See volume [scopes](#volume-scopes) for details on the different scopes.

### Listing volumes

`kontena volume ls`

### Deleting volumes

`kontena volume rm my-volume`

Deleting a volume that is still in use in any of the services will fail.

## Managing volumes with Kontena Stacks

Volumes can be defined also within Kontena Stacks using top level `volumes` key. When a stack is installed or upgraded, volumes not yet created within Kontena Grid are automatically created and managed by Kontena. Volume configuration cannot be changed after it has been created as Docker itself does not allow this.


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
    driver: rexray
    scope: instance
    driver_opts:
      size: 30G
```

Volumes are defined under top-level `volumes` key using the same well-known syntax from docker-compose.

The needed options depend on the volume driver used so make sure you check the volume driver capabilities.

## Volume scopes

Volume scopes define how the volumes will be "instantiated" when they are used in services.

Valid scopes are: `instance`, `stack` or `grid`.

The suitable scope depends highly on the service using the data and the volume driver providing the actual data persistence.

### Scope: instance

Instance scoped volumes are created per service instance so in practice each service instance will get it's own volume created.

Suitable for services where each instance should have their own data and possible data replication happens on application layer.

### Scope: stack

Stack scoped volumes are created once per stack per node. This means that services within the same stack and running on same node will use the same Docker volume.

Suitable for services which need to share the same data between different instances and the volume driver takes care of the data replication between volumes created on different nodes.

### Scope: grid

Grid scoped volumes are created once per grid per node.

Suitable for services and stacks which need to share the same data between different services/stacks and the volume driver takes care of the data replication between volumes created on different nodes.
