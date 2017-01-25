---
title: Highly available Kontena Master
---

# Running Kontena master in HA setup

Kontena master can be run in HA setup where multiple instances of the Kontena master for one highly available logical master.

## Requirements for HA

- Master nodes:
  - Any modern Linux distribution with support for Docker and docker-compose. CoreOS and Ubuntu are more heavily tested.
  -
- MongoDB cluster:
  - 3 node MongoDB replica-set is recommended

    Using provided services such as Compose.io can give huge operational benefits with some additional costs.

    **Note:** When using DBaaS services, make sure you can run the database in the same datacenter as you run your masters. If not there will be severe latencies in the database operations that could cause un-anticipated failures.

## Running Kontena masters

Running multiple master instances is as simple as running single instance. The key is to point all the master instances to the same database cluster and to use exact same configuration for all master instances.

### Setting Kontena master HA with docker-compose

If you are setting up Kontena master using docker-compose you can use following configuration:

```yaml
version: '2'
services:
  master:
    image: kontena/server:latest
    container_name: kontena-server-api
    restart: unless-stopped
    environment:
      - RACK_ENV=production
      - MONGODB_URI=mongodb://<user>:<password>@mongodb-1:10481,mongodb-2:10481/kontena-master?replicaSet=kontena-master
      - VAULT_KEY=somerandomverylongstringthathasatleastsixtyfourchars
      - VAULT_IV=somerandomverylongstringthathasatleastsixtyfourchars
      - INITIAL_ADMIN_CODE=loginwiththiscodetomaster
    ports:
      - 80:9292
```
Make sure all the instances are using same environment configuration values.

Spin up Kontena masters on as many nodes you feel comfortable to make the system highly available. Usually two or three nodes are sufficient.

### Setting up master with Kontena CLI plugins

Most of the Kontena CLI provisioning plugins support parameter `--mongodb-uri`. With this you can create multiple master instances and point them to the same MongoDB replica-set to achieve high availability. For example:
```bash
$ kontena aws master create --mongodb-uri mongodb://<user>:<password>@mongodb-1:10481,mongodb-2:10481/kontena-master?replicaSet=kontena-master
```

## Load balancing

As both Kontena CLI and agents connect to the Kontena master using http protocol there should be a loadbalancer distributing the connections to different master instances. SSL termination should be enable on the loadbalancer as the Kontena master accepts only plain HTTP traffic. Natural way to achieve loadbalancing is to utilize cloud provided solutions such as ELB/ALB.

If using an provided solution is not an option you can setup your own preferred loadbalancer (nginx, caddy, traefik, ...) or use Kontena HAProxy

# Additional details

Kontena master instances will use the provided MongoDB replica-set to elect a leader in the "cluster". Leader is responsible to coordinate some of the tasks including: service re-scheduling decisions and communication to Kontena cloud.
