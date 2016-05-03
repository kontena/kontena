---
title: kontena.yml
toc_order: 1
---

# Kontena.yml reference

Kontena.yml is a file in YAML format that defines a [Kontena application](../using-kontena/applications.md) with one or more services. It uses the same syntax and keys as Docker-compose, however not all keys are supported. The default name for this file is kontena.yml, although other filenames are supported.

Each key defined in kontena.yml will create a service with that name. The image key is mandatory. Other keys are optional.

#### image

The image used to deploy this service in docker format.

```
image: ubuntu:latest
```

```
image: kontena/haproxy:latest
```

```
image: registry.kontena.local/ghost:latest
```

#### affinity

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
    - service==wordpress
```

#### cap_add, cap_drop

Add or drop container capabilities.

```
cap_add:
  - ALL

cap_drop:
  - NET_ADMIN
  - SYS_ADMIN
```

#### command

Recall the optional COMMAND

```
bundle exec thin -p 3000
```

#### cpu_shares

By default, all containers get the same proportion of CPU cycles.
This proportion can be modified by changing the container’s CPU share
weighting relative to the weighting of all other running containers.
[Learn more](https://docs.docker.com/engine/reference/run/#cpu-share-constraints)

```
cpu_shares: 1024
```

#### mem_limit, memswap_limit

Memory limits of the created containers. [Learn more](https://docs.docker.com/reference/run/#runtime-constraints-on-resources).

```
mem_limit: 512m
memswap_limit: 1024m
```

#### environment

A list of environment variables to be added in the service containers on launch. You can use either an array or a dictionary.

```
environment:
  - BACKEND_PORT=3306
  - FRONTEND_PORT=3306
  - MODE=tcp
```

#### env_file

A reference to file that contains environment variables.

```
env_file: production.env
```

#### secrets

A list of secrets to be added from vault to the service containers on launch.

```
secrets:
  - secret: CUSTOMER_DB_PASSWORD
    name: MYSQL_PASSWORD
    type: env
```

#### extends

Extend another service, in the current file or another, optionally overriding configuration. You can for example extend `docker-compose.yml` services and introduce only Kontena specific fields in `kontena.yml`.

**docker-compose.yml**

```
app:
  build: .
  links:
    - db:db
db:
  image: mysql:5.6
```

**kontena.yml**

```
app:
  extends:
    file: docker-compose.yml
    service: app   
  image: registry.kontena.local/app:latest
db:
  extends:
    file: docker-compose.yml
    service: app
  image: mysql:5.6
```

#### external_links
Link to services in the same grid outside application scope. `external_links` follow semantics similar to links.

```
external_links:
  - loadbalancer
  - common-redis:redis   
```

#### instances

Number of containers to run for this service (default: 1).

```
instances: 3
```

#### links

Link to another service. Either specify both the service name and the link alias (SERVICE:ALIAS), or just the service name (which will also be used for the alias).

```
links:
  - mysql:wordpress-mysql
```

#### ports

Expose ports. Specify both ports (HOST:CONTAINER).

```
ports:
  - "80:80"
  - "53160:53160/udp"
```

#### stateful

Mark service as stateful (default: false). Kontena will create and mount automatically a data volume container for the service.

```
stateful: false
```

#### user

The default user to run the first process

```
user: app_user
```

#### volumes

Mount paths as volumes, optionally specifying a path on the host machine. (HOST:CONTAINER), or an access mode (HOST:CONTAINER:ro).

```
volumes:
 - /var/lib/mysql
```

#### volumes_from

Mount all of the volumes from another service by specifying a service unique name.

```
volumes_from:
 - wordpress
```

```
volumes_from:
 - wordpress-%s
```
(`-%s` will be replaced with container number, eg first service container will get volumes from wordpress-1, second from wordpress-2 etc)

#### deploy

These Kontena spefic keys define how Kontena will schedule and orchestrate containers across different nodes. Read more about deployments [here](../using-kontena/deploy.md).

**strategy**

How to deploy service's containers to different host nodes.

```
deploy:
    strategy: ha
```

```
deploy:
    strategy: daemon
```

```
deploy:
    strategy: random
```

**wait_for_port**

Wait the port is responding before moving to deploy another instance.

```
instances: 3
deploy:
  strategy: ha
  wait_for_port: 3000
```

**min_health**
The minimum percentage (number between 0.0 - 1.0) of healthy instances that do not sacrifice overall service availability while deploying.

```
instances: 3
deploy:
  strategy: ha
  min_health: 0.5
```

#### hooks

**post_start**

```
hooks:
  post_start
    - name: sleep
      cmd: sleep 10
      instances: *
      oneshot: true
```

**pre_build**

`pre_build` hooks define executables that are executed before the actual docker image building. If multiple hooks are provided they are executed in the order defined. If any of the commands fail the build is aborted.

```
hooks:
  pre_build
    - name: npm install
      cmd: npm install
    - name: grunt
      cmd: grunt dist
```




#### log_driver

Specify the log driver for docker to use with all containers of this service. For details on available drivers and their configs see [Docker log drivers](https://docs.docker.com/reference/logging/overview/)

#### log_opts

Specify options for log driver

```
nginx:
  image: nginx:latest
  ports:
    - 80:80
  log_driver: fluentd
  log_opt:
    fluentd-address: 192.168.99.1:24224
    fluentd-tag: docker.{{.Name}}

```
