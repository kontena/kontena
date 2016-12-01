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

The Kontena Services associated with a stack are shown as `stackname/servicename` in the CLI.
Traditional Kontena Services created using `kontena service create` are not associated with a stack, and are shown without any `stackname` prefix.

Like Kontena Services, Kontena Stacks are also grid-specific.
The `kontena stack` commands operate on the current grid, unless using the `--grid` option to temporarily operate on a different grid.

## Usage

Kontena Stacks can be distributed as YAML files via the ***Stack Registry***, deployed via the ***Kontena Master*** to run as ***Service Containers*** within the ***Grid***.

### Stack Registry
The following Kontena CLI commands operate on the Kontena Cloud stack registry:

* `kontena stack registry push` - Push a stack into the stacks registry
* `kontena stack registry pull` - Pull a stack from the stacks registry
* `kontena stack registry search` - Search for stacks in the stacks registry
* `kontena stack registry show` - Show info about a stack in the stacks registry
* `kontena stack registry remove` - Remove a stack (or version) from the stacks registry

#### `kontena cloud login`

The stack registry uses your Kontena Cloud OAuth credentials to upload stack files.
You must upload any stack files named using the same username prefix as you have used when registering to the Kontena Cloud:

```
Authenticated to Kontena Cloud at https://cloud-api.kontena.io as terom
```

Stack files can be be downloaded and searched from the stack registry without any login.

#### `kontena stack registry pull terom/wordpress`

Download the newest version of the YAML stack file from the Kontena Stack Registry.

You can write the YAML to a local file using either your shell's `> kontena.yml` syntax, or the `-F kontena.yml` option:

```
Wrote 999 bytes to kontena.yml
```

#### `kontena stack registry pull terom/wordpress:0.3.3`

Download a specific version of the YAML stack file from the Kontena Stack Registry.

#### `kontena stack registry push wordpress/kontena.yml`

Upload the YAML stack file to the Kontena Cloud Stack Registry:

```
[done] Pushing terom/wordpress:0.3.4 to stacks registry    
```

The `username/stackname` and version information are read from within the given YAML file.
By default, the `kontena.yml` file in the current directory is uploaded.

#### `kontena stack registry search wordpress`


`kontena stack search wordpress`

Lists available stacks files having a name suffix matching the given search term.

```
NAME                                     VERSION    DESCRIPTION                             
jussi/wordpress                          0.1.0      Todo-app bundle, all required services within the stack
terom/wordpress                          0.3.5      Wordpress 4.6 + MariaDB 5.5
```

Omit the search term to list all available stacks.

#### `kontena stack registry show terom/wordpress`

Lists information and available versions of a given stack file.

```
terom/wordpress:
  latest_version: 0.3.5
  expose: -
  description: Wordpress 4.6 + MariaDB 5.5
  available_versions:
    - 0.3.5
    - 0.3.4
    - 0.3.3
    - 0.3.2
```

#### `kontena stack registry remove terom/wordpress:0.3.3`

Delete a specific version of a stack file uploaded to the stack registry.

```
About to delete terom/wordpress:0.3.3 from the stacks registry
> Destructive command. You can skip this prompt by running this command with --force option. Are you sure? Yes
 [done] Removing terom/wordpress from the registry
 ```

A deleted stack file version cannot be re-uploaded, but you can upload the stack file with a newer version number.

#### `kontena stack registry remove terom/redis`

Delete all versions of a stack file from the stack registry.

```
About to delete an entire stack and all of its versions from the stacks registry
Destructive command. To proceed, type "terom/redis" or re-run this command with --force option.
> Enter 'terom/redis' to confirm:  terom/redis
 [done] Removing terom/redis from the registry
```

A deleted stack file can be re-upload with a newer version number.

### Deploying Stacks
The following Kontena CLI commands are used to install local stack files to the Kontena Master, and deploy the stack services running and Grid nodes:

* `kontena stack build` - Build and push Docker images referenced by a stack file
* `kontena stack install` - Create a stack on the Kontena Master
* `kontena stack upgrade` - Upgrade a stack within the Grid
* `kontena stack deploy` - Deploy a stack to the Grid
* `kontena stack remove` - Remove a deployed stack

#### `kontena stack install --name wordpress-red --deploy wordpress/kontena.yml`

Install the stack from the YAML file to the master, creating a new named stack with associated services.
Use the `--deploy` flag to simultaneously deploy the stack services to the grid, spinning up the Docker containers.

```
 [done] Creating stack wordpress-red      
 [done] Deploying stack wordpress-red     
```

The stack services will now be visible in `kontena service ls`, and the service containers will be running on the grid's host nodes.
If you omit the `kontena stack install --deploy` flag, then you must run `kontena stacl deploy wordpress-red` separately.

Assuming the new `wordpress-red/wordpress` container is running on the host node at `192.168.66.102`, you can use `http://192.168.66.102:80/` to access the installed wordpress service.

#### `kontena stack install --name wordpress-green --deploy terom/wordpress`

Install and deploy the stack using the latest YAML file from the stack registry.

#### `kontena stack install --name wordpress-green --deploy terom/wordpress:4.6.1+mariadb5.`

Install and deploy the stack using the versioned YAML file from the stack registry.

#### `kontena stack remove wordpress-red`

Removes the installed stack and associated services, including any deployed containers.

```
Destructive command. To proceed, type "wordpress-red" or re-run this command with --force option.
> Enter 'wordpress-red' to confirm:  wordpress-red
 [done] Removing stack wordpress-red      
```

This command also removes all data volumes associated with stateful services within the stack.

### Deployed Stacks
The following Kontena CLI commands can be used to inspect and monitor named stacks deployed to the grid:

* `kontena stack list` - List installed stacks
* `kontena stack show` - Show stack details from the Grid
* `kontena stack logs` - Show logs from stack services
* `kontena stack monitor` - Monitor stack services

#### `kontena stack ls`

List installed stacks for the current Grid, and their deployment state.

```
NAME                                                         VERSION    SERVICES   STATE      EXPOSED PORTS                                     
⊝ registry                                                   0.16.3     1          running                                                      
⊝ wordpress                                                  0.3.0      2          running    *:80->80/tcp                                      
⊝ wordpress-red                                              0.3.0      2          running    *:80->80/tcp        
```

#### `kontena stack show wordpress`

Show further details about the deployed stack configuration.

```
wordpress:
  state: running
  created_at: 2016-11-28T10:45:19.105Z
  updated_at: 2016-11-28T10:45:19.105Z
  version: 0.3.0
  expose: -
  services:
    wordpress:
      image: wordpress:4.6
      status: running
      revision: 2
      stateful: yes
      scaling: 1
      strategy: ha
      deploy_opts:
        min_health: 0.8
      dns: wordpress.wordpress.development.kontena.local
      ports:
        - 80:80/tcp
    mysql:
      image: mariadb:5.5
      status: running
      revision: 1
      stateful: yes
      scaling: 1
      strategy: ha
      deploy_opts:
        min_health: 0.8
      dns: mysql.wordpress.development.kontena.local
```

#### `kontena service ls --stack wordpress`

You can use the `kontena service` commands to view further details about the state of the services within a stack:

```
NAME                                                         INSTANCES  STATEFUL STATE      EXPOSED PORTS                                     
⊝ wordpress/wordpress                                        1 / 1      yes      running    0.0.0.0:80->80/tcp                                
⊝ wordpress/mysql                                            1 / 1      yes      running      
```

The normal `kontena service show wordpress/wordpress` commands can be used to inspect the services within a stack.

#### `kontena stack logs --tail wordpress`

The standard `kontena ... logs` options also work for all services and containers belonging to the stack.

```
...
2016-11-28T10:51:04.000Z [wordpress-wordpress-1]: 172.17.0.1 - - [28/Nov/2016:10:51:04 +0000] "GET /2016/11/28/hello-world/ HTTP/1.1" 200 5043 "http://192.168.66.101/2016/11/28/hello-world/" "WordPress/4.6.1; http://192.168.66.101"
```

You can also use the `kontena service logs wordpress/mysql` commands to access logs for specific services within the stack.
The `kontena container logs core-01/wordpress-mysql-1` commands can be used to access logs for a specific service container instance.

#### `kontena stack monitor`

Show an overview of the deployed stack state:

```
grid: development
stack: wordpress
services:
  ■ mysql (1 instances)
  ■ wordpress (1 instances)
nodes:
  core-01 (2 instances)
  ■■
```

## details

### Linking services within the same stack

Because each stack is deployed using a separate DNS namespace, services within the same stack can use the bare DNS names of other services in the same stack for communication.
There is no need to explicitly link services within the same stack.

For the example `wordpress` and `mysql` services in the `wordpress` stack deployed to the `test` grid, Kontena will use the `wordpress.test.kontena.local` DNS domain.
Each service container will be registered with an instance hostname and service alias within the stack's domain, and configured to resolve hostnames from the stack's domain.
Any service within the stack can be configured to use the bare `mysql` DNS name to resolve the overlay network IP address of the `mysql-1.wordpress.kontena.local` container via the `mysql.wordpress.kontena.local` service alias.

Each deployed stack will have an separate DNS namespace, including multiple deployed copies of the same stack file.
The `wordpress` container in one stack will always use the `mysql` service in the same stack.

## Exposing services between stacks

Each stack can also expose a service for use by other stacks using the top-level `expose: ` entry in the YAML stack file.
Other services in different stacks can use the bare DNS name of the stack itself to connect to the exposed service.

For example, the internal Kontena Registry is deployed as a `registry` stack that exposes the internal `api` service.
The `registry.test.kontena.local` DNS name is an alias for the `api-1.registry.test.kontena.local` service container.
Other service containers and the host nodes can use the bare `registry` DNS name to connect to the Kontena Registry.

To expose multiple services from a stack, expose a Kontena load-balancer service within the stack, linked to each of the services to expose.
