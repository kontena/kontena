---
title: Deploy
toc_order: 6
---

# Deploy 
After you have split your application into services, the final step to get them up and running is to deploy them to host nodes. 

Kontena has built-in `kontena deploy` command that takes care of everything for you: scheduling services across cluster, pulling required images, linking services and more.

The typical workflow for starting a new application is basically a three-step process

1.	Create or choose Docker images for the services
2.	Describe the services in `kontena.yml`
3.	Finally, run `kontena deploy` command and Kontena will start and run your entire application

Kontena applications can be described in YAML file ([kontena.yml]((../references/kontena-yml.md))). Kontena.yml extends docker-compose.yml format by introducing some new attributes only supported in Kontena, for example scale of a service and deploy specific attributes. 

An example `kontena.yml` looks like this

```
wordpress:  
  image: wordpress:4.1
  stateful: true
  ports:
    - 8080:80
  links:
    - mysql:wordpress-mysql
  env_file: wordpress.env
mysql:  
  image: mariadb:5.5
  stateful: true
  environment:
   - MYSQL_ROOT_PASSWORD=secret
  deploy:
    strategy: ha
    wait_for_port: true
```

See the complete [Kontena.yml reference](../references/kontena-yml.md)

## Deployment strategies
Kontena can use different scheduling algorithms when deploying containers to more than one node. At the moment the following strategies are available:

**High Availability (HA)**

Service with `ha` strategy will deploy its containers to different host nodes. This means that the containers will be spread across all nodes.

```
deploy:
  strategy: ha
```

**Random**

Service with `random` strategy will deploy service containers to host nodes randomly.

```
deploy:
  strategy: random
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
