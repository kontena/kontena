---
title: Nodes
---

# Nodes

Each node is a machine running the `kontena-agent`. The nodes connect to the Kontena Master, which then schedules and deploys services onto those nodes.

## Connecting nodes

Nodes do not need to be explicitly created. The Kontena Master will automatically create new grid nodes for any `kontena-agent` connecting to the Kontena Master with the correct [grid token](grids#Grid Token).  

## Online nodes

Nodes will be considered as online so long as they have an active Websocket connection to the Kontena Master.
Grid service instances can be deployed to any online node, unless restricted using [service affinity filters](deploy#Affinity) or the [grid default affinity](grids#Default Affinity).

The `kontena node rm` command can not be used to remove online nodes. The node must first be terminated (using the `kontena <provider> node terminate` command), and can then be removed once offline.

## Offline nodes

If the agent's Websocket connection to the master is disconnected or times out, the server will mark the nodes as as offline.

Offline nodes will not have any new service instances scheduled to them. Any services with instances deployed to any offline nodes will be re-scheduled by the server, moving the instances to the remaining online nodes.

## Node labels

Host nodes can have arbitrary labels of the form `label` or `label=value`. These labels can be used for [service affinity filters](deploy#Affinity). Some special labels are also set by the node provisioning plugins, and are recognized by Kontena itself.

### `provider`

Nodes provisioned by `kontena <provider> node create` plugin commands will have node label such as `provider=aws`.

### `az`

Nodes provisioned by some plugins (`aws`, `azure`, `digitalocean`) will also have node label such as `az=us-west-a1`.

The `az` label is used by the [`ha` deployment strategy](deploy#High Availability (HA)) to distribute service instances across different availability zones.

### `ephemeral`

Nodes labeled as `ephemeral` will automatically be removed by the Kontena Master after they have been offline for longer than six hours (6h).
The nodes should not be [initial nodes](grids#Initial Nodes), and they should not have any stateful services deployed on them.

Ephemeral nodes are intended to be used for autoscaled nodes, which may be provisioned automatically, and then cleaned up once terminated.
