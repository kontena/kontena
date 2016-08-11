---
title: Docker Compose
---

# Running Kontena using Docker Compose

- [Prerequisities](docker-compose#prerequisities)
- [Installing Kontena Master](docker-compose#installing-kontena-master)
- [Installing Kontena Nodes](docker-compose#installing-kontena-nodes)

## Prerequisities

- Kontena Account
- Docker Engine & Docker Compose

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master using Docker Compose can be done with following steps:

**Step 1:** create `docker-compose.yml` file with following contents:

```
version: '2'
services:
  haproxy:
    image: kontena/haproxy:latest
    environment:
      - SSL_CERT
      - BACKEND_PORT=9292
    ports:
      - 8080:80
      - 8443:443
    networks:
      - kontena
  api:
    image: kontena/server:latest
    environment:
      - RACK_ENV=production
      - MONGODB_URI=mongodb://mongodb:27017/kontena
    networks:
      kontena:
        aliases:
          - kontena-server-api
  mongodb:
    image: mongo:3.0
    command: mongod --smallfiles
    volumes:
      - kontena-server-mongodb:/data/db
    networks:
      - kontena
networks:
  kontena:
    driver: bridge
```

**Step 2:** Run command `docker-compose up -d`


After Kontena Master is running you can connect to it by issuing login command. First user to login will be given master admin rights.

```
$ kontena login --name docker-compose http://localhost:8080/
```

## Installing Kontena Nodes

Before you can start provision nodes you must first switch cli scope to a grid. Grid can be thought as a cluster of nodes that can have members from multiple clouds and/or regions.

Switch to existing grid using following command:

```
$ kontena grid use <grid_name>
```

Or create a new grid using command:

```
$ kontena grid create --initial-size=<initial_size> my-grid
```

> Recommended minimum initial-size is 3. This means minimum number of nodes in a grid is 3.

Now you can start provision nodes to your host machines. First copy following `docker-compose.yml` file to each host:

```
agent:
  container_name: kontena-agent
  image: kontena/agent:latest
  net: host
  environment:
    - KONTENA_URI=wss://<master_ip>:8443/
    - KONTENA_TOKEN=<grid_token>
    - KONTENA_PEER_INTERFACE=eth1
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
```

- `KONTENA_URI` is uri to Kontena Master (use ws:// for non-tls connection)
- `KONTENA_TOKEN` is grid token, can be acquired from master using `kontena grid show my-grid` command

**Note!** While Kontena works ok even with just single Kontena Node, it is recommended to have at least 3 Kontena Nodes provisioned in a Grid.

After creating nodes, you can verify that they have joined Grid:

```
$ kontena node list
```
