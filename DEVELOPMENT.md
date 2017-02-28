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

```bash
docker-compose run --service-ports api
```

Then, in another window login to the master with the initial admin code (set in `docker-compose.yml`) -- NOTE: wait until the master is healthy (see (the issue about this)[https://github.com/kontena/kontena/issues/1460])

```shell
dontena master login --name devmaster --code initialadmincode http://localhost:9292
```

NOTE: If you have an existing master with the same name, you may reuse the id or delete the master, see `dontena cloud master`

Use Kontena Cloud for your master:

```shell
dontena master init-cloud --force
```

Invite your account as a `master_admin`:

```shell
dontena master users invite -r master_admin your.registered@email.at.kontena.cloud.com
```

Then login:

```shell
dontena master join --name devmaster http://localhost:9292 invit3c0d3
```

Now create the grid:

```shell
dontena grid create --token devtoken dev
```

Set the token to `agent/.env`

```shell
echo "KONTENA_TOKEN=$(dontena grid show --token dev)" > agent/.env
```

Now kill the `docker-compose run` in another window and start everything at once with:

```shell
docker-compose up
```

Verify that service creation and scaling works:

```bash
dontena node ls
dontena service create redis redis
dontena service scale redis 3
dontena service logs redis
```

## Development workflow

Make a change to `master` or `agent` and restart `docker-compose up` (with control+c)

## Re-creating everything

First remove all services to clean up docker so that the deploys to the next grid will work:

```
dontena service ls -q | xargs -L 1 dontena service rm --force
```

Then run:

```bash
docker-compose down
docker ps -aq -f name=kontena- | xargs docker rm -f
docker ps -aq -f name=weave | xargs docker rm -f
dontena cloud master rm
dontena master rm
```

and start from the beginning.
