---
title: kontena.yml
toc_order: 1
---

# Kontena.yml reference

Kontena.yml is a file in [YAML](http://yaml.org) format that defines a [Kontena application](../using-kontena/applications.md) with one or more [services]((../using-kontena/services.md)). It uses the same syntax and keys as [Docker Compose file](https://docs.docker.com/compose/compose-file/), however not all keys are supported. The default name for this file is kontena.yml, although other filenames are supported.

Each key defined in kontena.yml will create a service with that name prefixed with project name. The image key is mandatory. Other keys are optional.

You can use environment variables in configuration values with a Bash-like ${VARIABLE} syntax - see [variable substitution](#variable-substitution) for full details.


## Service configuration reference
> **Note:** Kontena supports both Docker Compose file versions respectively. See more details about versioning on [Docker Compose documentation](https://docs.docker.com/compose/compose-file/#versioning)

### Kontena specific keys

#### instances

Number of instences (replicas) to run for the service (default: 1).

```
instances: 1
```

#### stateful

Mark service as stateful (default: false). Kontena will create and mount automatically a data volume container for the service. This options also instructs scheduler to bind service instance to scheduled host so that volume can be mapped when service is updated.

```
stateful: true
```

#### secrets

A list of secrets to be added from the Kontena Vault to the service on launch.

```
secrets:
  - secret: CUSTOMER_DB_PASSWORD
    name: MYSQL_PASSWORD
    type: env
```

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

Wait the port is responding before service instance is considered as running.

```
deploy:
  wait_for_port: 3000
```

**min_health**
The minimum percentage (number between 0.0 - 1.0) of healthy instances that do not sacrifice overall service availability while deploying.

```
deploy:
  min_health: 0.5
```

**interval**
The interval of automatic redeploy of service. Format <number><unit>, where unit = min, h, d.
```
deploy:
  interval: 7d
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

#### hooks

**post_start**

```
hooks:
  post_start:
    - name: sleep
      cmd: sleep 10
      instances: *
      oneshot: true
```

**pre_build**

`pre_build` hooks define executables that are executed before the actual docker image building. If multiple hooks are provided they are executed in the order defined. If any of the commands fail the build is aborted.

```
hooks:
  pre_build:
    - name: npm install
      cmd: npm install
    - name: grunt
      cmd: grunt dist
```

### Supported Docker Compose keys

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

#### build

Build can be specified either as a string containing a path to the build context, or an object with the path specified under context and optionally dockerfile (version 2 only).

```
build: .
```

```
build:
  context: .
  dockerfile: alternate-dockerfile
```
Build arguments are supported in version 2 yaml format. They can be defined either as an array of strings or as hash:
```
build:
  context: .
  args:
    - arg1=foo
    - arg2=bar
```
```
build:
  context: .
  args:
    arg1: foo
    arg2: bar
    arg3:
```
Build arguments with only a key are resolved to their environment value on the machine the build is running on.

#### dockerfile
> **Note:** Version 1 only

Alternate Dockerfile.

```
dockerfile: Dockerfile-alternate
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

#### depends_on
> **Note:** Version 2 only

Express dependency between services. Kontena will create and deploy services in dependency order.

```
version: '2'
services:
  web:
    build: .
    depends_on:
      - db
      - redis
  redis:
    image: redis:latest
  db:
    image: postgres:latest
```

#### environment

A list of environment variables to be added in the service containers on launch. You can use either an array or a dictionary.

```
environment:
  - BACKEND_PORT=3306
  - FRONTEND_PORT=3306
  - MODE=tcp
```

```
environment:
  DB_HOST: ${project}-db.kontena.local
```

> **Note:** Kontena will add automatically the following environment variables to running service instances: KONTENA_SERVICE_ID, KONTENA_SERVICE_NAME, KONTENA_GRID_NAME, KONTENA_NODE_NAME


#### env_file

A reference to file that contains environment variables.

```
env_file: production.env
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

#### links

Link to another service. Either specify both the service name and the link alias (SERVICE:ALIAS), or just the service name (which will also be used for the alias).

```
links:
  - mysql:wordpress-mysql
```

With Kontena you can always reach services by their internal DNS (*service_name.grid.kontena.local*) and links are not needed for the service discovery.


Links also express dependency between services in the same way as `depends_on`, so they determine the order of service startup.

#### net
> **Note:** Version 1 only. In version 2 use [network_mode](#network_mode).

Network mode.

```
net: "bridge"
```

```
net: "host"
```

#### network_mode
> **Note:** Version 2 only.

Network mode.

```
network_mode: "bridge"
```

```
network_mode: "host"
```

#### pid
Sets the PID mode to the host PID mode.

```
pid: host
```

#### ports

Expose ports. Specify both ports (HOST:CONTAINER).

```
ports:
  - "80:80"
  - "53160:53160/udp"
  - "1.2.3.4:8443:443"
```

**Note:** If you use bind IP in the port exposure definition make sure you use proper affinity rules to bind the service to a node where this address is available.

#### privileged
Give extended privileges to service.

```
privileged: true
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
 - wordpress-%%s
```
(`-%%s` will be replaced with container number, eg first service container will get volumes from wordpress-1, second from wordpress-2 etc)

#### log_driver
> **Note:** Version 1 only. In version 2 use [logging](#logging) options

Specify the log driver for docker to use with all containers of this service. For details on available drivers and their configs see [Docker log drivers](https://docs.docker.com/reference/logging/overview/)

#### log_opts
> **Note:** Version 1 only. In version 2 use [logging](#logging) options

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

#### logging
> **Note** Version 2 file format only. In version 1, use log_driver and log_opt.

Logging configuration for the service.

```
logging:
  driver: syslog
  options:
    syslog-address: "tcp://192.168.0.42:123"
```

## Variable substitution

Your configuration options can contain environment variables. Kontena uses the variable values from the shell environment in which `kontena app` commands are run. For example, suppose the shell contains EXTERNAL_PORT=8000 and you supply this configuration:

```
web:
  build: .
  image: registry.kontena.local/my-app:latest
  ports:
    - "${EXTERNAL_PORT}:5000"
```

Referencing other services within the same application needs project prefix in the service name. You can use `${project}` variable for that:

```
web:  
  image: wordpress:latest
  environment:
    - WORDPRESS_DB_HOST=${project}-db
db:
  image: mariadb:latest
```

## Example kontena.yml

```
version: "2"
services:
  loadbalancer:
    image: kontena/lb:latest
    ports:
      - 80:80
  app:
    build: .  
    image: registry.kontena.local/example-app:latest
    instances: 2
    links:
      - loadbalancer
    environment:
      - DB_URL=%{project}-db.kontena.local
      - KONTENA_LB_INTERNAL_PORT=80
      - KONTENA_LB_VIRTUAL_HOSTS=www.my-app.com
    deploy:
      strategy: ha
      wait_for_port: 80
    hooks:
      post_start:
        - name: sleep
          cmd: sleep 10
          instances: *  
  db:
    image: mysql:5.6
    stateful: true
    volumes:
      - /var/lib/mysql
```
