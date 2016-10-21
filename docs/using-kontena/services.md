---
title: Services
---

# Services

A [Service](../core-concepts/architecture.md#services) is composed of Containers based on the same image file.

## Service Discovery

Each service instance is automatically registered in Kontena Grid distributed DNS service, which makes them discoverable through simple name lookups. For example: if a service is named as `nginx` and it has been scaled to two instances, then the first instance can be found via `nginx-1.<grid>.kontena.local` dns address, the second via `nginx-2.<grid>.kontena.local` etc. It's also possible to query service dns that returns all service instances records. For example, the `nginx.<grid>.kontena.local` dns address will return both `nginx-1` and `nginx-2` instance addresses in random order.

## Service High Availability

Kontena monitors the state of each service instance and actively manages to ensure the desired state of the service. This can be triggered when there are fewer healthy instances than the desired scale of your service, a node becomes unavailable or a service instance fails.

## Using Services

* [List Services](services#list-services)
* [Create a New Service](services#create-a-new-service)
* [Deploy Service](services#deploy-service)
* [Update Service](services#update-service)
* [Scale Service](services#scale-service)
* [Stop Service](services#stop-service)
* [Start Service](services#start-service)
* [Restart Service](services#restart-service)
* [Show Details](services#show-service-details)
* [Show Logs](services#show-service-logs)
* [Show Statistics](services#show-service-statistics)
* [Monitor Service Instances](services#monitor-service-instances)
* [Show Environment Variables](services#show-service-environment-variables)
* [Add Environment Variable](services#add-environment-variable-to-service)
* [Remove Environment Variable](services#remove-environment-variable-from-service)
* [Add Secret](services#add-secret-to-service)
* [Remove Secret](services#remove-secret-from-service)
* [Link Service](services#link-service)
* [Unlink Service](services#unlink-service)
* [Remove Service](services#remove-service)

### List Services

```
$ kontena service ls
```

**Options:**

```
--grid GRID                   Specify grid to use
```


### Create a New Service

```
$ kontena service create <name> <image>
```

**Examples:**

```
# Stateless service that exposes port 80
$ kontena service create -p 80:80 nginx nginx:latest

# Stateful service that does not expose any ports, but can be accessed from other services within same grid
$ kontena service create --stateful redis redis:latest
```

**Note:** The`kontena service create` command does not automatically deploy a service.
It must be done separately with `kontena service deploy`.

**Options:**

```
--grid GRID                   Specify grid to use
-p, --ports PORTS             Publish a service's port to the host
-e, --env ENV                 Set environment variables
-l, --link LINK               Add link to another service in the form of name:alias
-v, --volume VOLUME           Add a volume or bind mount it from the host
--volumes-from VOLUMES_FROM   Mount volumes from another container
-a, --affinity AFFINITY       Set service affinity
-c, --cpu-shares CPU_SHARES   CPU shares (relative weight)
-m, --memory MEMORY           Memory limit (format: <number><optional unit>, where unit = b, k, m or g)
--memory-swap MEMORY_SWAP     Total memory usage (memory + swap), set '-1' to disable swap (format: <number><optional unit>, where unit = b, k, m or g)
--cmd CMD                     Command to execute
--instances INSTANCES         How many instances should be deployed
-u, --user USER               Username who executes first process inside container
--stateful                    Set service as stateful (default: false)
--privileged                  Give extended privileges to this service (default: false)
--cap-add CAP_ADD             Add capabitilies
--cap-drop CAP_DROP           Drop capabitilies
--net NET                     Network mode
--log-driver LOG_DRIVER       Set logging driver
--log-opt LOG_OPT             Add logging options
--deploy-strategy STRATEGY    Deploy strategy to use (ha, random)
--deploy-wait-for-port PORT   Wait for port to respond when deploying
--deploy-min-health FLOAT     The minimum percentage (0.0 - 1.0) of healthy instances that do not sacrifice overall service availability while deploying
--pid PID                     Pid namespace to use
--secret SECRET               Import secret from Vault
```

### Deploy Service

```
$ kontena service deploy <name>
```

**Options:**

```
--grid GRID                   Specify grid to use
--force-deploy                Force deploy even if service does not have any changes
```

### Update Service

```
$ kontena service update <name>
```

**Note:** The `kontena service update` command does not automatically redeploy a stateful service.
It must be done separately with `kontena service deploy`.

**Options:**

```
--grid GRID                   Specify grid to use
--image IMAGE                 Docker image to use
-p, --ports PORT              Publish a service's port to the host
-e, --env ENV                 Set environment variables
-l, --link LINK               Add link to another service in the form of name:alias
-a, --affinity AFFINITY       Set service affinity
-c, --cpu-shares CPU_SHARES   CPU shares (relative weight)
-m, --memory MEMORY           Memory limit (format: <number><optional unit>, where unit = b, k, m or g)
--memory-swap MEMORY_SWAP     Total memory usage (memory + swap), set '-1' to disable swap (format: <number><optional unit>, where unit = b, k, m or g)
--cmd CMD                     Command to execute
--instances INSTANCES         How many instances should be deployed
-u, --user USER               Username who executes first process inside container
--privileged                  Give extended privileges to this service (default: false)
--cap-add CAP_ADD             Add capabitilies
--cap-drop CAP_DROP           Drop capabitilies
--net NET                     Network mode
--log-driver LOG_DRIVER       Set logging driver
--log-opt LOG_OPT             Add logging options
--deploy-strategy STRATEGY    Deploy strategy to use (ha, random)
--deploy-wait-for-port PORT   Wait for port to respond when deploying
--deploy-min-health FLOAT     The minimum percentage (0.0 - 1.0) of healthy instances that do not sacrifice overall service availability while deploying
--pid PID                     Pid namespace to use
--secret SECRET               Import secret from Vault
```

### Scale Service

```
$ kontena service scale <name> <number>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Stop Service

```
$ kontena service stop <name>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Start Service

```
$ kontena service start <name>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Restart Service

```
$ kontena service restart <name>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Show Service Details

```
$ kontena service show <name>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Show Service Logs

```
$ kontena service logs <name>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Show Service Statistics

```
$ kontena service stats <name>
```

**Options:**

```
--grid GRID                   Specify grid to use
-t, --tail                    Tail (follow) stats in real time (default: false)
```

### Monitor Service Instances

```
$ kontena service monitor <name>
```

**Options:**

```
--grid GRID                   Specify grid to use
--interval SECONDS            How often view is refreshed (default: 2)
```

### Show Service Environment Variables

```
$ kontena service env list <name>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Add Environment Variable to Service

```
$ kontena service env add <name> <env>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Remove Environment Variable from Service

```
$ kontena service env remove <name> <env>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Link Secret to Service

```
$ kontena service secret link <name> <secret>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Unlink Secret from Service

```
$ kontena service secret unlink <name> <secret>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Link Service

```
$ kontena service link <name> <target>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Unlink Service

```
$ kontena service unlink <name> <target>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Remove Service

```
$ kontena service remove <name>
```

**Options:**

```
--grid GRID                   Specify grid to use
```
