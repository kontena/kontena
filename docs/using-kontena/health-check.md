---
title: Health checks
---

# Health checks

Kontena comes with a mechanism to define a custom health check for each service. By default Kontena will only monitor the existence of service instances (containers) and will re-deploy or reschedule a service in the case of lost instances.

Sometimes the container will exist but the application running within the container becomes unresponsive. In such cases, a custom application-level health check will detect the unresponsive application.

## Configuring a custom health check

Configuring a custom health check is done by adding the configuration in the kontena.yml file:

```
version: '2'
services:
  web:
    image: nginx
    stateful: false
    health_check:
      protocol: http
      port: 80
      interval: 20
      uri: /health
      initial_delay: 10
      timeout: 2

  mysql:
    image: mysql
    stateful: true
    deploy:
      strategy: ha
      wait_for_port: 3306
    environment:
      - MYSQL_ALLOW_EMPTY_PASSWORD=true
    health_check:
      protocol: tcp
      port: 3306
      interval: 10
      initial_delay: 10
      timeout: 2
```
Options:
* `protocol`: protocol to use, either `http` or `tcp`
* `port`: port to use for the check. This is the port the application is using within the container.
* `interval`: how often the health check is performed. Defined in seconds.
* `uri`: The relative URI to use for the health check. Only used in http mode.
* `initial_delay`: The time to wait until the first check is performed after a service instance is created. Allows some time for the application to start up.
* `timeout`: How long Kontena will wait for a response. If no response is received within this timeframe the instance is considered unhealthy.

**Note** When performing tcp mode check, Kontena will only try to open a tcp socket connection to the specified port. If the connection is successful the instance is considered healthy.


## Kontena Load Balancer

Configuring a custom healthcheck on a service also ensures that the same health check is used by the Kontena Load Balancer, if the service is attached to one. When Kontena Load Balancer detects unhealthy instances, it will remove them from the routing. In practice this means that unhealthy instances will not get any traffic through the Kontena Load Balancer until they report being healthy again.

## Using the health status

Kontena Platform is actively monitoring the health status of all Kontena Services. Kontena Agent will automatically restart any container that is identified as `unhealthy`. Kontena Master will automatically re-deploy any Kontena Service that has too many unhealthy containers. This behaviour can be managed and configured by adjusting `min_health` deployment option (see [deploy](deploy.md)). 

The `min_health` deployment option is used to set the threshold for triggering Kontena Service re-deployment. If you specify `0.8` as the `min_health` option during deployment, Kontena Master will re-deploy your Kontena Service if the number of `unhealthy` containers for that Kontena Service exceeds 80%.

You can inspect the current health status for your Kontena Services using the Kontena CLI tool.