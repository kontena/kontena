---
title: kontena.yml
toc_order: 1
---

# Kontena.yml reference

Kontena.yml is a file in [YAML](http://yaml.org) format that defines a [Kontena Stack](../using-kontena/stacks.md) with one or more [services](../using-kontena/services.md). It uses the similar syntax and keys for services as a [Docker Compose file](https://docs.docker.com/compose/compose-file/). However, not all Docker Compose keys are [supported](docker-compose-support.md) in Kontena. The default name for this file is kontena.yml, although other filenames are supported.

Each service defined in kontena.yml will create a service with that name within the stack's namespace, shown as stack/service in the CLI. The image key is mandatory. Other keys are optional.

Each service is reachable by all other services in the same grid and discoverable by other services in the same stack by using the service name as a DNS hostname. See [networking](#networking) for full details.

You can use variables to set configuration values with a bash-like `${VARIABLE}` syntax. See [variable substitution](#variable-substitution) for full details.

## Stack configuration reference

#### stack
Stack identification. Use format `<username>/<stack_name>`.
```
stack: kontena/jenkins
```

#### version
Version number based on [Semantic Versioning](http://semver.org/).

```
version: 0.1.0
```

#### variables

Variables to be used to fill in values and to create conditional logic in the stack file.
See the complete [variables reference](kontena-yml-variables.md).

```
variables:
  mysql_root_pw:
    type: string
    from:
      prompt: Enter a root password for MySQL or leave empty to auto generate
      random_string: 16
services:
  mysql:
    environment:
      - "MYSQL_PASSWORD=${mysql_root_pw}"
```

#### expose

Expose a service from stack for use by other stacks. Read more about exposing services [here](https://kontena.io/docs/using-kontena/stacks#exposing-services-between-stacks).

```
expose: api
services:
  api:
    image: registry/api:latest
  db:
    image: mariadb:latest
```

## Service configuration reference
> **Note:** Kontena supports Docker Compose file version 2. For more details about Docker Compose versioning, see the [Docker Compose documentation](https://docs.docker.com/compose/compose-file/#versioning)

### Kontena specific keys

#### instances

Number of instances (replicas) to run for the service (default: 1).

```
instances: 1
```

#### stateful

Mark service as stateful (default: false). Kontena will create and automatically mount a data volume container for the service. This option also instructs the scheduler to bind the service instance to the scheduled host so that the volume can be mapped when the service is updated.

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

These Kontena-specific keys define how Kontena will schedule and orchestrate containers across different Nodes. Read more about deployments [here](../using-kontena/deploy.md).

**strategy**

How to deploy a Service's containers to different host Nodes.

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

Wait until the specified port is responding before considering the service instance to be running.

```
deploy:
  wait_for_port: 3000
```

**min_health**
The minimum percentage (expressed as a number in the range 0.0 - 1.0) of healthy instances that do not sacrifice overall service availability while deploying.

```
deploy:
  min_health: 0.5
```

**interval**
The interval of automatic redeploy of the service. Format <number><unit>, where unit = min, h, d.
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
  - label==provider=aws
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

`pre_build` hooks define executables that are executed before the actual Docker image is built. If multiple hooks are provided they are executed in the order defined. If any of the commands fail the build is aborted.

```
hooks:
  pre_build:
    - name: npm install
      cmd: npm install
    - name: grunt
      cmd: grunt dist
```

#### health_check

See information about configuring service health checks in [Using Kontena: Health checks](../using-kontena/health-check.md).

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

Build can be specified either as a string containing a path to the build context, or an object with the path specified under context and, optionally, a Dockerfile.

```
build: .
```

```
build:
  context: .
  dockerfile: alternate-dockerfile
```

Build arguments can be defined either as an array of strings or as a hash:

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

> **Note:** Kontena will automatically add the following environment variables to running service instances: KONTENA_SERVICE_ID, KONTENA_SERVICE_NAME, KONTENA_GRID_NAME, KONTENA_NODE_NAME


#### env_file

A reference to a file that contains environment variables.

```
env_file: production.env
```

#### extends

Extend another service, in the current file, another file or a stack in the stacks registry, optionally overriding configuration. You can, for example, extend `docker-compose.yml` services and introduce only Kontena-specific fields in `kontena.yml`.

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
redis:
  extends:
    stack: user/redis:1.0.0
    service: redis
```

#### links

Link to another service. Either specify both the service name and the link alias (SERVICE:ALIAS), or just the service name (which will also be used for the alias). Link can also point to a service from other stack. Notation is then (STACK/SERVICE:ALIAS).

```
links:
  - mysql:wordpress-mysql
  - common/loadbalancer
```

With Kontena you can always reach services by their internal DNS (*service_name.stack.grid.kontena.local*) and links are not needed for the service discovery. See [networking](#networking) for full details.

Links also express dependency between services in the same way as `depends_on`, so they determine the order of service startup.


#### network_mode

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

Expose ports. Specify both ports using the format (HOST:CONTAINER).

```
ports:
  - "80:80"
  - "53160:53160/udp"
  - "1.2.3.4:8443:443"
```

**Note:** If you use bind IP in the port exposure definition, be sure to use proper affinity rules to bind the service to a Node where this address is available.

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

Data volume:

```
volumes:
 - /var/lib/mysql
```

Bind mount host directory as a volume:

```
volumes:
 - /data/mysql:/var/lib/mysql
```

Named volumes are supported in the service declaration, but not in the top-level `volumes` key. When defining named volume in the service declaration the default driver configured by the Docker Engine will be used (in most cases, this is the local driver). If volume does not exist it will be created.

```
volumes:
 - mysql:/var/lib/mysql
```


#### volumes_from

Mount all of the volumes from another service by specifying a service unique name.

```
volumes_from:
 - wordpress-%s
```

(The `-%s` will be replaced with the service instance number; for example, the first service container will get volumes from wordpress-1, the second from wordpress-2, etc.)

You can only use `volumes_from` between services within the same stack. Use the plain name of the service without any stack prefix.

#### logging

Logging configuration for the service.

```
logging:
  driver: syslog
  options:
    syslog-address: "tcp://192.168.0.42:123"
```

```
 nginx:
   image: nginx:latest
   ports:
     - 80:80
   logging:
     driver: fluentd
     options:
       fluentd-address: 192.168.99.1:24224
       # {% raw %}
       # raw .. endraw needed to avoid parsing {{ .. }} as a Liquid tag.
       fluentd-tag: docker.{{.Name}}
       # {% endraw %}
 ```

## Volumes

Kontena stack yaml support volumes to be used which are created using `kontena volume create ...` command or the corresponding REST API on master.

```
stack: redis
description: Just a simple Redis stack with volume
version: 0.0.1
services:
  redis:
    image: redis:3.2-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data

volumes:
  redis-data:
    external:
      name: testVol

```

The used volumes must be introduced in the stack yaml file and mapped to the created volume by name. This creates the option to use "alias" names for grid level volumes within stack yaml. Other option is to introduce the volume with `external: true`:
```
volumes:
  redis-data:
    external: true
```

In this case Kontena expects to find a volume called `redis-data` before the stack can be installed or upgraded.

## Networking
Each service within the same stack is both reachable by other services and discoverable by them at a hostname identical to the service name.

Each service can use DNS to resolve the hostname of a service such as `web` or `db` to the IP address of that service's containers. For example, web’s application code could connect to the URL postgres://db:5432 and start using the Postgres database.

```
web:
  image: myapp:latest

db:
  image: postgres:latest
  stateful: true
```

To connect to other services within the same grid please use the complete internal DNS addresses:
`servicename.stackname.${GRID}.kontena.local`

## Variable substitution

**Note:** Since Kontena 1.1.0 you can no longer use environment variables that have not been declared in the `variables` section of the YAML. To use environment variables on your local machine, you have to use the `env` resolver as documented in [variables reference](kontena-yml-variables.md).


```yaml
variables:
  mysql_root_pw: # variable name
    type: string
    from:
      env: MYSQL_ROOT_PW # read from local environment variable MYSQL_ROOT_PW

services:
  mysql:
    image: mysql:latest
    environment:
      - "MYSQL_ROOT_PW=${mysql_root_pw}" # Variable value will be substituted when the stack file is parsed
```

Kontena CLI will automatically define `GRID` and `STACK` variables for you and those variables are available for variable substitution also inside the variables section of the YAML.

## Templating

For more advanced templating the kontena.yml can use  [Liquid](https://shopify.github.io/liquid/) template language. The variables are also available inside the template tags.

```yaml
variables:
  target:
    type: enum
    options:
      - production
      - staging

services:
  app:
  image: app:latest
  environment:
    # {% if target == "staging" %}
    - "DEBUG=true"
    # {% endif %}
```

Notice that the file has to be valid YAML before and after template rendering.

## Example kontena.yml

```yaml
stack: kontena/example-app
version: 0.1.0
variables:
  mysql_root_pw:
    type: string
    from:
      prompt: Enter a root password for MySQL or leave empty to auto generate
      random_string: 16
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
      - DB_URL=db
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
    environment:
      - MYSQL_ROOT_PASSWORD=${mysql_root_pw}
    volumes:
      - /var/lib/mysql
```
