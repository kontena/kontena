---
title: Docker Compose
---

# Running Kontena using Docker Compose

- [Prerequisites](docker-compose#prerequisites)
- [Installing Kontena Master](docker-compose#installing-kontena-master)
- [Installing Kontena Nodes](docker-compose#installing-kontena-nodes)

## Prerequisites

- [Kontena CLI](cli)
- Docker Engine version 1.10 or later
- Docker Compose

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master using Docker Compose can be accomplished via the following steps:

**Step 1:** create a `docker-compose.yml` file with the following contents:

```yml
version: '2'
services:
  haproxy:
    image: kontena/haproxy:latest
    container_name: kontena-server-haproxy
    restart: always
    environment:
      - SSL_CERT=**None**
      - BACKENDS=kontena-server-api:9292
    depends_on:
      - master
    ports:
      - 80:80
      - 443:443    
  master:
    image: kontena/server:latest
    container_name: kontena-server-api
    restart: always
    environment:
      - RACK_ENV=production
      - MONGODB_URI=mongodb://mongodb:27017/kontena
      - VAULT_KEY=somerandomverylongstringthathasatleastsixtyfourchars
      - VAULT_IV=somerandomverylongstringthathasatleastsixtyfourchars
      - INITIAL_ADMIN_CODE=loginwiththiscodetomaster
    depends_on:
      - mongodb
  mongodb:
    image: mongo:3.0
    container_name: kontena-server-mongo
    restart: always
    command: mongod --smallfiles
    volumes:
      - kontena-server-mongo:/data/db
volumes:
  kontena-server-mongo:
```

**Note!** `VAULT_KEY` & `VAULT_IV` should be random strings. They can be generated from bash:

```sh
$ cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1
```

**Note!** If you want to use a SSL certificate you can use the following command to obtain the correct value for `SSL_CERT`:
```sh
$ awk 1 ORS='\\n' /path/to/cert_file
```

If you don't have an SSL certificate, you can generate a self-signed certificate with:
```sh
$ openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout privateKey.key -out certificate.crt
cat certificate.crt privateKey.key > cert.pem
```

**Step 2:** Run the command `docker-compose up -d`

After Kontena Master has started you can authenticate as the Kontena Master internal administrator using the `INITIAL_ADMIN_CODE` you provided. Refer to [authetication](../../using-kontena/authentication.md) for information on logging in with the admin code and how to configure [Kontena Cloud](https://cloud.kontena.io) as the authentication provider.

## Installing Kontena Nodes

Before you can start provisioning nodes you must first switch the CLI scope to a Grid. A Grid can be thought of as a cluster of nodes that can have members from multiple clouds and/or regions.

Create a new Grid using the command:

```sh
$ kontena grid create --initial-size=<initial_size> my-grid
```

Or switch to an existing Grid using the following command:

```sh
$ kontena grid use <grid_name>
```

> The recommended minimum initial-size is three. This means the minimum number of Nodes in a Grid is three.

Now you can start provisioning nodes to your host machines.

**Step 1:** copy the following `docker-compose.yml` file to each host:

```yml
agent:
  container_name: kontena-agent
  image: kontena/agent:latest
  net: host
  restart: always
  environment:
    - KONTENA_URI=wss://<master_ip>/
    - KONTENA_TOKEN=<grid_token>
    - KONTENA_PEER_INTERFACE=eth1
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
```

- `KONTENA_URI` is the uri to Kontena Master (use ws:// for a non-tls connection)
- `KONTENA_TOKEN` is the Kontena Grid token, which can be acquired from Kontena Master using the `kontena grid show my-grid` command
- `KONTENA_PEER_INTERFACE` is the network interface that is used to connect the other nodes in the grid.

**Step 2:** Run the command `docker-compose up -d`

To allow the Kontena Agent to pull from Kontena's built-in private image registry, you must add `--insecure-registry="10.81.0.0/16"` to the Docker daemon options on the host machine. The most platform-independent way to do this is with the `/etc/docker/daemon.json` config file:

```sh
$ cat > /etc/docker/daemon.json <<DOCKERCONFIG
{
  "labels": ["region=<name_here>"],
  "insecure-registries": ["10.81.0.0/16"]
}
DOCKERCONFIG
```

**Note!** While Kontena works ok even with just a single Kontena Node, it is recommended to have at least 3 Kontena Nodes provisioned in a Grid.

After creating nodes, you can verify that they have joined a Grid:

```sh
$ kontena node list
```

#### DNS setup

To make Kontena overlay DNS addresses to work on the host side you must add the docker0 bridge IP address into the local DNS server list. If your OS is using `resolvconf` you can do it like this:
```
echo nameserver 172.17.0.1 | resolvconf -a lo.kontena-docker
```
Refer to your OS distribution documentation on how to setup DNS servers.

Replace `172.17.0.1` with your local `docker0` bridge IP address. You can find that for example with:
```
ip addr show docker0
```

If your system is using a local resolver you could add Kontena DNS as a forward zone.  E.g. for 'unbound' use:
```
    cat > /etc/unbound/unbound.conf.d/kontena.conf <<CONF
server:
  private-domain: "kontena.local"
  domain-insecure: "kontena.local"

forward-zone:
  name: "kontena.local."
  forward-addr: $DOCKER_GW_IP
CONF
```
