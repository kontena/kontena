---
title: Deploy
toc_order: 7
---

## Deployment strategies
Kontena can use different scheduling algorithms when deploying services to more than one node. At the moment the following strategies are available:

**High Availability (HA)**

Service with `ha` strategy will deploy its instances to different host nodes. This means that the service instances will be spread across all nodes.

```
deploy:
  strategy: ha
```

**Daemon**

Service with `daemon` strategy will deploy given number of instances to all nodes.

```
deploy:
  strategy: daemon
```


**Random**

Service with `random` strategy will deploy service containers to host nodes randomly.

```
deploy:
  strategy: random
```

**Wait for port**

When a service has multiple instances and `wait_for_port` definition, Kontena's scheduler will wait that container is responding to port before starting to deploy another instance. This way it is possible to achieve zero-downtime deploys.

```
instances: 3
deploy:
  wait_for_port: true
```

## Scheduling Conditions
When creating services, you can direct the host(s) of where the containers should be launched based on scheduling rules.

### Affinity
An affinity condition is when Kontena is trying to find a field that matches (`==`) given value. An anti-affinity condition is when Kontena is trying to find a field that does not match (`!=`) given value.

Kontena has the ability to compare values against host node name and labels and container name.

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
