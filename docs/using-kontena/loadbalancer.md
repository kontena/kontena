---
title: Load Balancer
toc_order: 6
---

# Kontena Load Balancer

Load balancers are used to distribute traffic between services. Therefore, having a fully featured, high performance and reliable load balancer is one of the most essential component for building applications composed of multiple services.

With Kontena, developers can enjoy the built-in load balancer that is based on [HAproxy](http://www.haproxy.org/). It is fully managed by Kontena orchestration and enable consistent, portable load balancing on any infrastructure where Kontena Nodes are running.

The Kontena Load Balancer key features:

* Zero downtime when load balancer configuration changes
* Fully automated configuration
* Dynamic routing
* Support for TCP and HTTP traffic

## Using Kontena Load Balancer

Kontena Load Balancer is a HAproxy / confd service that is configured to watch changes in etcd. Load Balancers may be described in `kontena.yml` and services are connected automatically by linking services to these load balancer services. If load balanced service is scaled/re-deployed then the load balancer will reload it's configuration on the fly without dropping connections.

An example of Internet facing load balancer:

```
internet_lb:
  image: kontena/lb:latest
  ports:
    - 80:80

web:
  image: nginx:latest
  environment:
    - KONTENA_LB_MODE=http
    - KONTENA_LB_BALANCE=roundrobin
    - KONTENA_LB_INTERNAL_PORT=80
    - KONTENA_LB_VIRTUAL_HOSTS=www.kontena.io,kontena.io
  links:
    - internet_lb
api:
  image: registry.kontena.local/restapi:latest
  environment:
    - KONTENA_LB_MODE=http
    - KONTENA_LB_BALANCE=roundrobin
    - KONTENA_LB_INTERNAL_PORT=8080
    - KONTENA_LB_VIRTUAL_PATH=/api
  links:
    - internet_lb
```

An example of internal TCP load balancer:

```
galera_lb:
  image: kontena/lb:latest

galera:
  image: registry.kontena.local/galera:latest
  environment:
    - KONTENA_LB_MODE=tcp
    - KONTENA_LB_BALANCE=leastcon
    - KONTENA_LB_EXTERNAL_PORT=3306
    - KONTENA_LB_INTERNAL_PORT=3306
  links:
    - galera_lb
```


## Config Env variables for balanced services

* `KONTENA_LB_MODE`: mode of load balancing, possible values: http (default), tcp
* `KONTENA_LB_BALANCE`: load balancing algorithm to use, possible values are: roundrobin (default), source, leastcon
* `KONTENA_LB_INTERNAL_PORT`: service port that is attached to load balancer
* `KONTENA_LB_EXTERNAL_PORT`: service port that load balancer starts to listen (only for tcp mode)
* `KONTENA_LB_VIRTUAL_HOSTS`: comma separated list of virtual hosts (only for http mode)
* `KONTENA_LB_VIRTUAL_PATH`: path that is used to match request, example "/api" (only for http mode)
* `KONTENA_LB_CUSTOM_SETTINGS`: extra settings, each line will be appended to either related backend section or listen session in the HAProxy configuration file

## Config env variables for load balancer

* `SSL_CERTS`: one or more ssl certificates that are used to terminate ssl connections, first certificate is used as default