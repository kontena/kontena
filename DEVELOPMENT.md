# Developing Kontena

With `docker-compose`

## Initial Setup

### CLI

Link a development version of your local cli:

```
$ ln -s $(pwd)/cli/bin/kontena /usr/local/bin/dontena
$ cd cli && bundle install
$ dontena version
```

### Server and Agent

First you need to create a grid, so start the api (aka server or master) and mongodb from `docker-compose.yml` with

```
$ docker-compose run --service-ports api
```

Then, in another window login to the master with

```
$ dontena login http://localhost:9292
Email: youremail@registered-with-kontena-auth-server.com
Password: **********
```

Now create the grid:

```
$ dontena grid create local
Using grid: local

$ dontena grid show local
local:
  uri: ws://localhost:9292
  token: thisIsTheTokenYouNeedToGiveToTheAgentInTheNextStep==
  stats:
    nodes: 0 of 0
    cpus: 0
    load: 0.0 0.0 0.0
    memory: 0.0 of 0.0 GB
    filesystem: 0.0 of 0.0 GB
    users: 1
    services: 0
    containers: 0
```

Set the token to `agent/.env`

```
$ dontena grid show local | grep token: | sed -e 's/  token: /KONTENA_TOKEN=/' > agent/.env
```

Now kill the `docker-compose run`


## Development workflow

Start services with

```
$ docker-compose up
```

Verfify that for example service creation and scaling works:

```
$ dontena service create redis redis
$ dontena service scale redis 3
$ dontena service logs -t redis
```

Now make a change to api or agent and restart `docker-compose up` (with control+c)
