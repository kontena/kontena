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
The following Kontena CLI commands operate on stack files and the stack registry:

* `kontena stack build` - Build Docker images referenced by a stack file
* `kontena stack pull` - Pull a stack file from the stack registry
* `kontena stack push` - Push a stack file to the stack registry
* `kontena stack push -d` - Delete a stack file from the stack registry
* `kontena stack search` - Search for stack files in the stack registry
* `kontena stack info` - Show info about a stack in the stack registry

The following Kontena CLI commands operate on named stacks deployed to the grid:

* `kontena stack list` - List stacks deployed to the Grid
* `kontena stack show` - Show stack details from the Grid
* `kontena stack install` - Deploy a stack to the Kontena Master
* `kontena stack upgrade` - Upgrade a stack within the Grid
* `kontena stack deploy` - Deploy a stack to the Grid
* `kontena stack logs` - Show logs from stack services
* `kontena stack monitor` - Monitor stack services
* `kontena stack remove` - Remove a deployed stack
