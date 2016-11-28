---
title: Stacks
---

# Stacks

Kontena Stacks are pre-packaged and reusable collections of Kontena services with associated configuration in the form of a YAML file.
These Kontena Stack files can be distributed via the Kontena Stack Registry, and installed to the Kontena Master for deployment to the Grid.
The Kontena Master deploys each stack as a set of Kontena Services, running as Docker containers on the host nodes.
The service containers run the Docker images referenced in the stack file.

Multiple instances of a stack file can be installed on the same Kontena grid, assigning an unique name to each deployed stack.
The service containers for each stack are run within a separate `$stack.$grid.kontena.local` DNS namespace.
The service containers can connect to the bare DNS names of other services in the same stack.
Stacks can also expose a service, allowing other stacks to use the bare DNS name of the exposing stack to connect to the exposed service.

## Usage

Kontena Stacks can be distributed as YAML files via the ***Stack Registry***, deployed via the ***Kontena Master*** to run as ***Service Containers*** within the ***Grid***.

### Stack Registry
The following Kontena CLI commands operate on the Kontena Cloud stack registry:

* `kontena stack pull` - Pull a stack file from the stack registry
* `kontena stack push` - Push a stack file to the stack registry
* `kontena stack push -d` - Delete a stack file from the stack registry
* `kontena stack search` - Search for stack files in the stack registry
* `kontena stack info` - Show info about a stack in the stack registry

#### `kontena stack pull terom/wordpress`

Download the YAML stack file from the Kontena Cloud Stack Registry:

```
stack: terom/wordpress
version: 0.3.0
variables:
  wordpress-mysql-root:
    type: string
    from:
      vault: wordpress-mysql-root
      random_string: 32
    to:
      vault: wordpress-mysql-root
  wordpress-mysql-password:
    type: string
    from:
      vault: wordpress-mysql-password
      random_string: 32
    to:
      vault: wordpress-mysql-password
services:
  wordpress:
    image: wordpress:4.6
    stateful: true
    ports:
      - 80:80
    environment:
      WORDPRESS_DB_HOST: mysql
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_NAME: wordpress
    secrets:
      - secret: wordpress-mysql-password
        name: WORDPRESS_DB_PASSWORD
        type: env
  mysql:
    image: mariadb:5.5
    stateful: true
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
    secrets:
      - secret: wordpress-mysql-root
        name: MYSQL_ROOT_PASSWORD
        type: env
      - secret: wordpress-mysql-password
        name: MYSQL_PASSWORD
        type: env
```

You can write the YAML to a local file using either `-f kontena.yml`, or your shell's `> kontena.yml` syntax.

#### `kontena stack push examples/wordpress/kontena.ymlexamples/wordpress/kontena.yml`

Upload the YAML stack file to the Kontena Cloud Stack Registry:

```
Successfully pushed terom/wordpress:0.3.1 to Stacks registry
```

The `username/stackname` and version information are read from the given YAML file, which defaults to the `kontena.yml` file in the current directory.

#### `kontena stack search wordpress`

Lists available stacks having a name suffix matching the given search term.

```
terom/wordpress
```

Omit the search term to list all available stacks.

#### `kontena stack info terom/wordpress`

Lists available versions for a given stack.

```
CURRENT VERSION
-----------------
* Version: 0.3.3

AVAILABLE VERSIONS
-------------------
0.3.3
0.3.2
```

#### `bundle exec bin/kontena stack push -d terom/wordpress:0.3.2`

```
About to delete terom/wordpress:0.3.2 from the registry
> Destructive command. You can skip this prompt by running this command with --force option. Are you sure? Yes
Stack terom/wordpress:0.3.2 deleted successfully
```

#### `kontena stack push -d terom/wordpress`

```
About to delete an entire stack and all of its versions from the registry
Destructive command. To proceed, type "terom/wordpress" or re-run this command with --force option.
> Enter 'terom/wordpress' to confirm:  terom/wordpress
Stack terom/wordpress deleted successfully
```

### Stack files
The following Kontena CLI commands operate on local stack files:

* `kontena stack build` - Build and push Docker images referenced by a stack file
* `kontena stack install` - Create a stack on the Kontena Master
* `kontena stack upgrade` - Upgrade a stack within the Grid

### Deployed Stacks
The following Kontena CLI commands operate on named stacks deployed to the grid:

* `kontena stack list` - List installed stacks
* `kontena stack show` - Show stack details from the Grid
* `kontena stack deploy` - Deploy a stack to the Grid
* `kontena stack logs` - Show logs from stack services
* `kontena stack monitor` - Monitor stack services
* `kontena stack remove` - Remove a deployed stack
