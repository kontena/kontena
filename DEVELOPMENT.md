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

Then, in another window login to the master with the initial admin code (set in `docker-compose.yml`)

```
$ dontena master login --name devmaster --code initialadmincode http://localhost:9292
```

NOTE: If you have an existing master with the same name, you may reuse the id or delete the master, see `dontena cloud master`

Use Kontena Cloud for your master:

```
$ dontena master init-cloud --force
```

Invite your account as a `master_admin`:

```
$ dontena master users invite your.registered@email.at.kontena.cloud.com
```

NOTE: before logging in take a note of the invite code and before using that add `master_admin` role to yourself by:

```
$ dontena master users role add master_admin your.registered@email.at.kontena.cloud.com
```

Then login:

```
$ dontena master join --name devmaster http://localhost:9292 invit3c0d3
```

Now create the grid:

```
$ dontena grid create --token devtoken dev
```

Set the token to `agent/.env`

```
$ echo "KONTENA_TOKEN=$(dontena grid show --token dev)" > agent/.env
```

Now kill the `docker-compose run` in another window and start everything at once with:

```
$ docker-compose up
```

Verify that service creation and scaling works:

```
$ dontena service create redis redis
$ dontena service scale redis 3
$ dontena service logs -t redis
```

## Development workflow

Now make a change to api or agent and restart `docker-compose up` (with control+c)

## Starting again

Run

```
$ docker-compose down
```

and start from the beginning
