---
title: Services
---

# Services

A [Service](../core-concepts/architecture.md#services) is composed of Containers based on the same image file.

## Service Discovery

Each Service instance is automatically registered in the Kontena Grid distributed DNS service, which makes services discoverable through simple name lookups. For example, if a service is named `nginx` and it has been scaled to two instances, then the first instance can be found via the `nginx-1.<grid>.kontena.local` DNS address, the second via `nginx-2.<grid>.kontena.local`, etc. It is also possible to query a Service DNS to return all service instance records. For example, the `nginx.<grid>.kontena.local` DNS address will return both the `nginx-1` and `nginx-2` instance addresses, in random order.

## Service High Availability

Kontena monitors the state of each Service instance and actively manages it to ensure the desired state of the Service. Action is triggered when there are fewer healthy instances than the desired scale of your Service, when a node becomes unavailable or when a Service instance fails.

## Using Services

* [List Services](services.md#list-services)
* [Create a New Service](services.md#create-a-new-service)
* [Deploy Service](services.md#deploy-service)
* [Update Service](services.md#update-service)
* [Scale Service](services.md#scale-service)
* [Stop Service](services.md#stop-service)
* [Start Service](services.md#start-service)
* [Restart Service](services.md#restart-service)
* [Show Details](services.md#show-service-details)
* [Show Logs](services.md#show-service-logs)
* [Show Event Logs](services.md#show-service-event-logs)
* [Show Statistics](services.md#show-service-statistics)
* [Monitor Service Instances](services.md#monitor-service-instances)
* [Show Environment Variables](services.md#show-service-environment-variables)
* [Add Environment Variable](services.md#add-environment-variable-to-service)
* [Remove Environment Variable](services.md#remove-environment-variable-from-service)
* [Add Secret](services.md#add-secret-to-service)
* [Remove Secret](services.md#remove-secret-from-service)
* [Link Service](services.md#link-service)
* [Unlink Service](services.md#unlink-service)
* [Remove Service](services.md#remove-service)

### List Services

```
$ kontena service ls
```

**Options:**

```
--grid GRID                   Specify Grid to use
```


### Create a New Service

```
$ kontena service create <name> <image>
```

**Examples:**

```
# Stateless Service that exposes port 80
$ kontena service create -p 80:80 nginx nginx:latest

# Stateful Service that does not expose any ports, but can be accessed from other Services within same grid
$ kontena service create --stateful redis redis:latest
```

**Note:** The`kontena service create` command does not automatically deploy a service.
That must be done separately with `kontena service deploy`.

**Options:**

```
--grid GRID                   Specify Grid to use
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
--grid GRID                   Specify Grid to use
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
--grid GRID                   Specify Grid to use
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
--grid GRID                   Specify Grid to use
```

### Stop Service

```
$ kontena service stop <name>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Start Service

```
$ kontena service start <name>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Restart Service

```
$ kontena service restart <name>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Show Service Details

```
$ kontena service show <name>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Show Service Logs

```
$ kontena service logs <name>
```

**Options:**

```
--grid GRID                   Specify grid to use
-t, --tail                    Tail (follow) logs (default: false)
--lines LINES                 Number of lines to show from the end of the logs (default: 100)
--since SINCE                 Show logs since given timestamp
-i, --instance INSTANCE       Show only given instance specific logs
```

### Show Service Event Logs

```
$ kontena service events <name>
```

**Options:**

```
--grid GRID                   Specify grid to use
-t, --tail                    Tail (follow) logs (default: false)
--lines LINES                 Number of lines to show from the end of the logs (default: 100)
--since SINCE                 Show logs since given timestamp
```

### Show Service Statistics

```
$ kontena service stats <name>
```

**Options:**

```
--grid GRID                   Specify Grid to use
-t, --tail                    Tail (follow) stats in real time (default: false)
```

### Monitor Service Instances

```
$ kontena service monitor <name>
```

**Options:**

```
--grid GRID                   Specify Grid to use
--interval SECONDS            How often view is refreshed (default: 2)
```

### Show Service Environment Variables

```
$ kontena service env list <name>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Add Environment Variable to Service

```
$ kontena service env add <name> <env>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Remove Environment Variable from Service

```
$ kontena service env remove <name> <env>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Link Secret to Service

```
$ kontena service secret link <name> <secret>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Unlink Secret from Service

```
$ kontena service secret unlink <name> <secret>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Link Service

```
$ kontena service link <name> <target>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Unlink Service

```
$ kontena service unlink <name> <target>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Remove Service

```
$ kontena service remove <name>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```
