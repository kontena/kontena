---
title: Kontena.yml reference
toc_order: 1
---

# Kontena.yml reference

Kontena.yml is a file in YAML format that define one or more services. The default name for this file is kontena.yml, although other filenames are supported.

Each key defined in kontena.yml will create a service with that name. The image key is mandatory. Other keys are optional.

**image**

The image used to deploy this service in docker format.

```
image: ubuntu:latest
image: kontena/haproxy:latest
image: registry.kontena.local/ghost:latest
```

**affinity**

Affinity conditions of hosts where containers should be launched

```
affinity:
    - node==node1.kontena.io
```

```
affinity:
    - label==AWS
```

```
affinity:
    - container!=wordpress
```

**cap_add, cap_drop**

Add or drop container capabilities.

```
cap_add:
  - ALL
  
cap_drop:
  - NET_ADMIN
  - SYS_ADMIN
```

**cmd**

Recall the optional COMMAND`

```
bundle exec thin -p 3000
```

**cpu_shares, mem_limit, memswap_limit**

The relative CPU priority and the memory limit of the created containers. [Learn more](https://docs.docker.com/reference/run/#runtime-constraints-on-resources).
```
cpu_shares: 73
mem_limit: 1000000000
```

**environment**

A list of environment variables to be added in the service containers on launch. You can use either an array or a dictionary.

```
environment:
  - BACKEND_PORT=3306
  - FRONTEND_PORT=3306
  - MODE=tcp
``` 

**env_file**

A reference to file that contains environment variables.

```
env_file: production.env
```

**instances**

Number of containers to run for this service (default: 1). 

```
instances: 3
```

**links**

Link to another service. Either specify both the service name and the link alias (SERVICE:ALIAS), or just the service name (which will also be used for the alias).

```
links:
  - myslq:wordpress-mysql
```

**ports**

Expose ports. Either specify both ports (HOST:CONTAINER), or just the container port (a random host port will be chosen).

```
ports:
  - "80:80"
  - "53160:53160/udp"
```

**stateful**

Mark service as stateful (default: false). Kontena will create and mount automatically a data volume container for the service.

```
stateful: false
```

**user**

The default user to run the first process

```
user: app_user
```

**volumes**

Mount paths as volumes, optionally specifying a path on the host machine. (HOST:CONTAINER), or an access mode (HOST:CONTAINER:ro).

```
volumes:
 - /var/lib/mysql
```

**volumes_from**

Mount all of the volumes from another service by specifying a service unique name.

```
volumes_from:
 - wordpress
```

**deploy**

**strategy**
How to deploy service's containers to different host nodes.

```
deploy:
    strategy: ha
```

```
deploy:
    strategy: random
```
