---
title: Nodes
---

# Nodes

Each node is a machine running the `kontena-agent`. The nodes connect to the Kontena Master, which then schedules and deploys services onto those nodes.

### Provisioning nodes

There are two methods for provisioning new nodes, which differ in terms of how the `kontena-agent` websocket connections are authenticated, and how the nodes are managed.

This documentation applies to custom node installs.
See [Installing Kontena](../getting-started/installing/) for platform-specific documentation on installing new nodes using the Kontena CLI plugins, which automates the process.

#### Node Token

Nodes can be provisioned with unique node tokens using the `KONTENA_NODE_TOKEN=` environment variable.

Nodes provisioned with a Node token must be created beforehand using `kontena node create`.
The server will generate a new token for the node, or `--token` can be used to provide an unique pre-generated token.
Use the CLI `kontena node env` command to generate the `/etc/kontena-agent.env` configuration required for the `kontena-agent` on the new node, including the `KONTENA_NODE_TOKEN?`.

The Kontena Master will use the node token provided by the agent to associate the connection with an existing grid node, as authenticated by the node token.
The grid node will be associated with the Node ID provided by the first agent to connect using the node token.
The same node token cannot be used by any other agent with a different Node ID.
Attempting to provision multiple nodes with the same node token will result in connection errors: `Incorrect node token, already used by a different node`

The node token can also be reset using `kontena node reset`.
This will force the agent to disconnect (unless using `--no-reset-connection`), and require the agent `/etc/kontena-agent.env` configuration to be updated using the new `KONTENA_NODE_TOKEN=` from `kontena node env` before it will be able to reconnect.

Decomissioning a node using `kontena node rm` will also revoke the node token, preventing further agent connections to the master using the node token that the node was provisioned with.
If the agent is still connected, removing the node will forcibly disconnect the agent within the next keepalive interval (0-30s): `ERROR -- Kontena::WebsocketClient: master indicates that this agent should not reconnect: host node UXTT:TPWP:6OQM:3UKS:EPB4:MOQD:DYYT:N42X:VSR5:IIM3:VDCP:22IC has been removed`

#### Grid Token

Nodes can be provisioned with a shared [grid token](grids.md#Grid Token) using the `KONTENA_TOKEN=` environment variable.

Nodes provisioned with a Grid token do not need to be explicitly created beforehand.
Use the CLI `kontena grid env` command to generate the environment variables required for configuring `kontena-agent` on the new node, including the `KONTENA_TOKEN`.

The Kontena Master will use the Node ID provided by the agent to associate the connection with a node in the correct grid, as authenticated by the grid token.
The master will automatically create a new grid node if a new `kontena-agent` connects with a valid grid token and previously unknown Node ID.

The grid token cannot be revoked.
Nodes provisioned using grid tokens that are still online cannot be removed using `kontena node rm`, as the agent would quickly reconnect and the node would get re-created by the server.
If an offline node using a grid token is removed, and the agent later reconnects, the node will re-appear in the grid.

Existing nodes configured to connect with grid tokens can be upgraded to use node tokens using `kontena node reset`.
This will force the agent to disconnect, and require the agent `/etc/kontena-agent.env` configuration to be updated using the new `KONTENA_NODE_TOKEN=` from `kontena node env` before it will be able to reconnect.
The `kontena node reset --clear-token` command can be used to revert back to the grid token.

### Online nodes

Nodes will be considered as online so long as they have an active Websocket connection to the Kontena Master.
The agents will ping the server every 30 seconds, and expect a response within 5 seconds.
The server will ping each agent every 30 seconds, and expect a response within 5 seconds.

The server and agent will log warning messages if the websocket keepalive ping delay goes over half of the timeout. Use [`WEBSOCKET_TIMEOUT`](../references/environment-variables.md) to adjust the timeout.

Grid service instances can be deployed to any online node, unless restricted using [service affinity filters](deploy.md#affinity) or the [grid default affinity](grids.md#default-affinity).
When a host node comes online, existing grid services will be re-scheduled by the server to deploy new [`daemon`-strategy](deploy.md#daemon) instances or re-balance other service instances onto the new node.
The re-scheduling of stateless grid services will happen within 20 seconds of the node coming online.

### Offline nodes

If the agent's Websocket connection to the master is disconnected or times out, the server will mark the nodes as as offline.

Offline nodes will not have any new service instances scheduled to them.
Any stateless services with instances deployed to any offline nodes will be re-scheduled by the server, moving the instances to the remaining online nodes.
The re-scheduling of grid services will happen after the node offline grace period, which depends on the deployment strategy in use.

#### Deployment Strategy Offline Grace Periods

- `daemon`: 10 minutes
- `ha`: 2 minutes
- `random`: 30 seconds

### Decomissioning nodes

Use the `kontena node rm` command to decomission a node.

If the node was provisioned using a grid token, then the node must first be terminated to stop the agent and force it to disconnect from the master, and then the `kontena node rm` command can be used to remove the offline node.
The `kontena node rm` command will refuse to remove an online node that was provisioned with a grid token.

Nodes created using `kontena node create` and provisioned using a node token can be removed using `kontena node rm`, even if they are online.
The agent will be disconnected and will be unable to reconnect, as the node token will be invalidated.
This can be used as a security feature to isolate compromised nodes from the grid.

Use the `kontena <provider> node terminate` plugin commands to terminate nodes and remove them from the Kontena Master.
Alternatively, power off and destroy the node instance directly from the provider's control panel, and wait for the nodes to be offline before removing them from the CLI.

Any service instances deployed to a removed node will be invalidated, and can be re-deployed to a different node.
This happens automatically for stateless services, similar to behavior of offline nodes, but without the grace period.
For stateful services, any instances on removed nodes will be re-scheduled on the next service deploy, and the replacement service instances will lose their state.

## Node ID
Nodes are uniquely identified by their Docker Engine ID, as shown in `docker info`:

```
 ID: 44C7:P5OM:NBJT:WXHV:6EDU:67T5:YDMX:4YPU:PF6D:VUH5:7LE7:5RC7
```

### Node ID Conflicts
Provisioning multiple nodes with the same Node ID / Docker ID will cause the agents to interfere with eachother, as the server will consider each of the connecting agents to be the same `kontena-agent` process running on the same node.

In case of node ID conflicts, the agents will get disconnected from the master with errors: `connection closed with code 4041: host node ... connection conflict with new connection at ...`

This can happen when using cloned disk images to provision nodes, where the cloned disk images already have Docker pre-installed.

## Node labels

Host nodes can have arbitrary labels of the form `label` or `label=value`. These labels can be used for [service affinity filters](deploy.md#affinity). Some special labels are also set by the node provisioning plugins, and are recognized by Kontena itself.

### `provider`

Nodes provisioned by `kontena <provider> node create` plugin commands will have node label such as `provider=aws`.

### `az`

Nodes provisioned by some plugins (`aws`, `azure`, `digitalocean`) will also have node label such as `az=us-west-a1`.

The `az` label is used by the [`ha` deployment strategy](deploy.md#high-availability-ha) to distribute service instances across different availability zones.

### `ephemeral`

Nodes labeled as `ephemeral=yes` will automatically be removed by the Kontena Master after they have been offline for longer than six hours (6h).
The nodes should not be [initial nodes](grids.md#initial-nodes), and they should not have any stateful services deployed on them.

Ephemeral nodes are intended to be used for autoscaled nodes, which may be provisioned automatically, and then cleaned up once terminated.

Ephemeral nodes will not be available for scheduling of stateful services as the service state is only persisted on local disk.

## Manage Nodes

#### Create a new Node

Create a new node named `core-03` in the current grid:

```
$ kontena node create core-03
 [done] Creating core-03 node      
```

The server will generate a new node token by default, if not using `--token` to supply a pre-generated node token.

#### List Nodes

```
$ kontena node list
NAME        VERSION     STATUS    INITIAL   LABELS
⊛ core-01   1.4.0       online    1 / 1     provider=vagrant
⊛ core-02   1.4.0       online    -         provider=vagrant
⊝ core-03   1.4.0       offline   -         -
```

#### Generate `kontena-agent` configuration

Generate environment variables required for provisioning the `kontena-agent`:

```
$ kontena node env core-03
KONTENA_URI=ws://192.168.66.1:9292/
KONTENA_NODE_TOKEN=yempbjWHbZLhc66gB0mAFXKS8HzS/daDwCfnHC+UfrJo5wkhQ6hpr8XKY5nUdH+h6CH81Y9bQIc4IgTcEEjQCQ==
```

Also see `kontena grid env` if using grid tokens for provisioning.

#### Remove a Node

```
$ kontena node rm core-03
Destructive command. To proceed, type "core-03" or re-run this command with --force option.
> Enter 'core-03' to confirm:  test-node
 [done] Removing test-node node from development grid      
```

The node must already be offline if it was provisioned using a grid token.
If the node was created using `kontena node create`, then the node token will be invalidated.
See [Decomissioning nodes](#decomissioning-nodes).
