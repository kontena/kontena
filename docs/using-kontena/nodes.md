---
title: Nodes
---

# Nodes

Each node is a machine running the `kontena-agent`. The nodes connect to the Kontena Master, which then schedules and deploys services onto those nodes.

### Provisioning nodes

Nodes do not need to be explicitly created. The Kontena Master will automatically create new grid nodes for any `kontena-agent` connecting to the Kontena Master with the correct [grid token](grids.md#Grid Token).

Nodes are identified by their Docker Engine ID, as shown in `docker info`:

```
 ID: 44C7:P5OM:NBJT:WXHV:6EDU:67T5:YDMX:4YPU:PF6D:VUH5:7LE7:5RC7
```

### Online nodes

Nodes will be considered as online so long as they have an active Websocket connection to the Kontena Master.
The agents will ping the server every 30 seconds, and expect a response within 2 seconds.
The server will ping each agent every 30 seconds, and expect a response within 5 seconds.

Grid service instances can be deployed to any online node, unless restricted using [service affinity filters](deploy.md#affinity) or the [grid default affinity](grids.md#default-affinity).
When a host node comes online, existing grid services will be re-scheduled by the server to deploy new [`daemon`-strategy](deploy.md#daemon) instances or re-balance other service instances onto the new node.
The re-schduling of grid services will happen within 20 seconds of the node coming online.

### Offline nodes

If the agent's Websocket connection to the master is disconnected or times out, the server will mark the nodes as as offline.

Offline nodes will not have any new service instances scheduled to them.
Any services with instances deployed to any offline nodes will be re-scheduled by the server, moving the instances to the remaining online nodes.
The re-schduling of grid services will happen within 20 seconds of the node being marked as disconnected.

### Decomissioning nodes

To decomission a node, you must first terminate it, and you can then remove the offline node from the Kontena Master.

The `kontena node rm` command can not be used to remove an online node.
Use the `kontena <provider> node terminate` plugin commands to terminate nodes and remove them from the Kontena Master.
Alternatively, power off and destroy the node instance directly from the provider's control panel, and wait for the nodes to be offline before removing them from the CLI.

## Node labels

Host nodes can have arbitrary labels of the form `label` or `label=value`. These labels can be used for [service affinity filters](deploy.md#affinity). Some special labels are also set by the node provisioning plugins, and are recognized by Kontena itself.

### `provider`

Nodes provisioned by `kontena <provider> node create` plugin commands will have node label such as `provider=aws`.

### `az`

Nodes provisioned by some plugins (`aws`, `azure`, `digitalocean`) will also have node label such as `az=us-west-a1`.

The `az` label is used by the [`ha` deployment strategy](deploy.md#high-availability-ha) to distribute service instances across different availability zones.

### `ephemeral`

Nodes labeled as `ephemeral` will automatically be removed by the Kontena Master after they have been offline for longer than six hours (6h).
The nodes should not be [initial nodes](grids.md#initial-nodes), and they should not have any stateful services deployed on them.

Ephemeral nodes are intended to be used for autoscaled nodes, which may be provisioned automatically, and then cleaned up once terminated.
