---
title: Docker Compose
---

# Running Kontena using Docker Compose

- [Prerequisities](docker-compose#prerequisities)
- [Installing Kontena Master](docker-compose#installing-kontena-master)
- [Installing Kontena Nodes](docker-compose#installing-kontena-nodes)

## Prerequisities

- Kontena Account
- Docker Engine (<= 1.10 ) & Docker Compose

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master using Docker Compose can be done with the following steps:

**Step 1:** create `docker-compose.yml` file with the following contents:

```
version: '2'
services:
  haproxy:
    image: kontena/haproxy:latest
    container_name: kontena-master-haproxy
    environment:
      - SSL_CERT=**None**
      - BACKEND_PORT=9292
    ports:
      - 80:80
      - 443:443    
  master:
    image: kontena/server:latest
    container_name: kontena-master
    environment:
      - RACK_ENV=production
      - MONGODB_URI=mongodb://mongodb:27017/kontena
      - VAULT_KEY=somerandomverylongstringthathasatleastsixtyfourchars
      - VAULT_IV=somerandomverylongstringthathasatleastsixtyfourchars
    depends_on:
      - mongodb
  mongodb:
    image: mongo:3.0
    container_name: kontena-master-mongodb
    command: mongod --smallfiles
    volumes:
      - kontena-master-mongodb:/data/db    
volumes:
  kontena-master-mongodb:
```

**Note!** `VAULT_KEY` & `VAULT_IV` should be random strings. They can be generated from bash:

```
$ cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1
```

**Note!** If you want to use a SSL certificate you can use the following command to obtain the correct value for `SSL_CERT`:
```
$ awk 1 ORS='\\n' /path/to/cert_file
```

If you don't have a SSL certificate you can generate a self-signed certificate and use that:
```
$ openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout privateKey.key -out certificate.crt
cat certificate.crt privateKey.key > cert.pem
```

**Step 2:** Run the command `docker-compose up -d`

After Kontena Master has provisioned you will be automatically authenticated as the Master administrator and the default grid 'test' is set as the current grid.

## Installing Kontena Nodes

Before you can start provisioning nodes you must first switch cli scope to a grid. A Grid can be thought of as a cluster of nodes that can have members from multiple clouds and/or regions.

Create a new grid using the command:

```
$ kontena grid create --initial-size=<initial_size> my-grid
```

Or switch to an existing grid using the following command:

```
$ kontena grid use <grid_name>
```

> The recommended minimum initial-size is 3. This means the minimum number of nodes in a grid is 3.

Now you can start provisioning nodes to your host machines.

**Step 1:** copy the following `docker-compose.yml` file to each host:

```
agent:
  container_name: kontena-agent
  image: kontena/agent:latest
  net: host
  environment:
    - KONTENA_URI=wss://<master_ip>/
    - KONTENA_TOKEN=<grid_token>
    - KONTENA_PEER_INTERFACE=eth1
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
```

- `KONTENA_URI` is the uri to Kontena Master (use ws:// for a non-tls connection)
- `KONTENA_TOKEN` is the grid token, which can be acquired from master using the `kontena grid show my-grid` command
- `KONTENA_PEER_INTERFACE` is the network interface that is used to connect the other nodes in the grid.

**Step 2:** Run the command `docker-compose up -d`

To allow Kontena agent to pull from Kontena's built-in private image registry you must add `--insecure-registry="10.81.0.0/19"` to Docker daemon options on the host machine.

**Note!** While Kontena works ok even with just a single Kontena Node, it is recommended to have at least 3 Kontena Nodes provisioned in a Grid.

After creating nodes, you can verify that they have joined a Grid:

```
$ kontena node list
```
