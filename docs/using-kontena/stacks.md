---
title: Stacks
---

# Stacks

Kontena YAML stack files can be distributed the Kontena Stack Registry, and installed to the Kontena Master for deployment to the Grid.
The Kontena master deploys each stack as a collection of services containers running on the Host Nodes.
The service containers for each stack run in a separate `$stack.$grid.kontena.local` DNS namespace.

The following Kontena CLI commands operate on stack files and the stack registry:

* `kontena stack build` - Build Docker images referenced by a stack file
* `kontena stack push` - Push a stack file to the stack registry
* `kontena stack pull` - Pull a stack file from the stack registry
* `kontena stack search` - Search for stack files in the stack registry

The following Kontena CLI commands operate on stacks deployed to the grid:

* `kontena stack list` - List stacks deployed to the Grid
* `kontena stack show` - Show stack details from the Grid
* `kontena stack install` - Deploy a stack to the Kontena Master
* `kontena stack upgrade` - Upgrade a stack within the Grid
* `kontena stack deploy` - Deploy a stack to the Grid
* `kontena stack logs` - Show logs from stack services
* `kontena stack monitor` - Monitor stack services
* `kontena stack remove` - Remove a deployed stack
