---
title: Deployment Strategies
---
# Deployment Strategies

Kontena can use different scheduling algorithms when deploying services to more than one Node. At the moment the following strategies are available:

### High Availability (HA)

A service with `ha` strategy will deploy its instances to different host nodes. This means that the service instances will be spread across all availability zones/Nodes. Availability zones are resolved from Node labels; for example, `az=a1` means that that Node belongs to availability zone `a1`.

```yaml
deploy:
  strategy: ha
```

### Daemon

A service with `daemon` strategy will deploy the given number of instances to all Nodes.

```yaml
deploy:
  strategy: daemon
```

### Random

A service with `random` strategy will deploy service containers to host Nodes randomly.

```yaml
deploy:
  strategy: random
```

## Other Deploy Options

### Wait for port

When a service has multiple instances and a `wait_for_port` definition, Kontena's scheduler will wait until that container is responding on the given port before starting to deploy another instance. This makes it possible to achieve zero-downtime deploys.

```yaml
instances: 3
deploy:
  wait_for_port: 1234
```

### Min health

A number (percentage) between 0.0 and 1.0 that is multiplied with the instance count. This is the minimum number of healthy nodes that do not sacrifice overall service availability. Kontena will make sure, during the deploy process, that at any point in time this number of healthy instances are up.

```yaml
instances: 3
deploy:
  min_health: 0.5
```

The default `min_health` is 1.0, which means no instances can be deployed in parallel (in that case, deploys will progress one-by-one). A value of 0.5 means that during a deploy half of the instances can be deployed in parallel.

### Interval

Deployment interval of service. A service will be automatically scheduled for deployment after this time unless it has been scheduled by other events. This can be used as an "erosion-resistance" mechanism.

```yaml
deploy:
  interval: 8h
```

## Scheduling Conditions

When creating services, you can direct the Node(s) to which the containers should be launched based on scheduling rules.

### Affinity

An affinity condition happens when Kontena is trying to find a field that matches (`==`) a given value. An anti-affinity condition happens when Kontena is trying to find a field that does not match (`!=`) a given value.

```yaml
affinity:
  - "<condition 1>"
  - "<condition N>"
```

Kontena has the ability to compare values against node name, node labels, service name and container name.

For example:

- `node==node-1` will match node with name `node-1`
- `node!=node-1` will match all nodes, except `node-1`
- `label==az=1a` will match all nodes with label `az=1a`
- `label!=az=1a` will match all nodes, except nodes with label `az=1a`
- `service==mysql` will match all nodes that have instance of service `mysql` deployed
- `service!=mysql` will match all nodes, except those that have instance of service `mysql` deployed
- `container==mysql.db-1` will match all nodes that have container `mysql.db-1`
- `container!=mysql.db-1` will match all nodes, except those that have container `mysql.db-1`

#### Soft Affinity

By default affinities are hard-enforced. If an affinity is not met, the service won't be scheduled. With soft affinity the scheduler tries to meet the rule. If rule is not met, the scheduler will discard the filter and schedule the service according to other filters / deployment strategy.

Soft affinities are expressed with `~`.

For example:

- `label==~az-1a` tries to match nodes with name `node-1`. Affinity is discarded if none of the nodes have matching name.
- `service!=~mysql` tries to match nodes which don't have instance of `mysql` service deployed. Affinity is discarded if all nodes have instance of `mysql` service deployed.