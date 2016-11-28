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

* `kontena stack registry push` - Push a stack into the stacks registry
* `kontena stack registry pull` - Pull a stack from the stacks registry
* `kontena stack registry search` - Search for stacks in the stacks registry
* `kontena stack registry info` - Show info about a stack in the stacks registry
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
