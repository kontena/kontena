---
title: Deployments
---
# Deployments

## Deployment Strategies
Kontena can use different scheduling algorithms when deploying services to more than one Node. At the moment the following strategies are available:

### High Availability (HA)

A service with `ha` strategy will deploy its instances to different host nodes. This means that the service instances will be spread across all availability zones/Nodes. Availability zones are resolved from Node labels; for example, `az=a1` means that that Node belongs to availability zone `a1`.

```
deploy:
  strategy: ha
```

### Daemon

A service with `daemon` strategy will deploy the given number of instances to all Nodes.

```
deploy:
  strategy: daemon
```

### Random

A service with `random` strategy will deploy service containers to host Nodes randomly.

```
deploy:
  strategy: random
```

## Other Deploy Options

### Wait for port

When a service has multiple instances and a `wait_for_port` definition, Kontena's scheduler will wait until that container is responding on the given port before starting to deploy another instance. This makes it possible to achieve zero-downtime deploys.

```
instances: 3
deploy:
  wait_for_port: 1234
```

### Min health

A number (percentage) between 0.0 and 1.0 that is multiplied with the instance count. This is the minimum number of healthy nodes that do not sacrifice overall service availability. Kontena will make sure, during the deploy process, that at any point in time this number of healthy instances are up.

```
instances: 3
deploy:
  min_health: 0.5
```

The default `min_health` is 1.0, which means no instances can be deployed in parallel (in that case, deploys will progress one-by-one). A value of 0.5 means that during a deploy half of the instances can be deployed in parallel.

### Interval

Deployment interval of service. A service will be automatically scheduled for deployment after this time unless it has been scheduled by other events. This can be used as an "erosion-resistance" mechanism.

```
deploy:
  interval: 8h
```

## Scheduling Conditions

When creating services, you can direct the Node(s) to which the containers should be launched based on scheduling rules.

### Affinity

An affinity condition happens when Kontena is trying to find a field that matches (`==`) a given value. An anti-affinity condition happens when Kontena is trying to find a field that does not match (`!=`) a given value.

Kontena has the ability to compare values against Node name, container, labels and Service name.

```
affinity:
    - node==node1.kontena.io
```

```
affinity:
    - container==service-name-1
```

```
affinity:
    - label==az=1a
```

```
affinity:
    - service==mysql
```
