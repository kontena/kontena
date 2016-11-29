---
title: Packet
---

# Running Kontena on Packet

- [Prerequisites](packet#prerequisites)
- [Installing Packet Plugin](packet#installing-kontena-packet-plugin)
- [Installing Kontena Master](packet#installing-kontena-master)
- [Installing Kontena Nodes](packet#installing-kontena-nodes)
- [Packet Command Reference](packet#packet-command-reference)

## Prerequisites

- [Kontena CLI](cli)
- Packet.net Account. Visit [https://www.packet.net/promo/kontena/](https://www.packet.net/promo/kontena/) to get started

## Installing Kontena Packet Plugin

```
$ kontena plugin install packet
```

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master to Packet can be accomplished by issuing the following command:

```
$ kontena packet master create \
  --token <packet_api_token> \
  --project <project_id> \
  --type baremetal_0
```

After the Kontena Master has been provisioned, you will be automatically authenticated as the Kontena Master internal administrator and the default Grid 'test' is set as the current Grid.

## Installing Kontena Nodes

Before you can start provisioning Nodes you must first switch the CLI scope to a Grid. A Grid can be thought as a cluster of Nodes that can have members from multiple clouds and/or regions.

Switch to existing Grid using the following command:

```
$ kontena grid use <grid_name>
```

Or create a new Grid using the command:

```
$ kontena grid create --initial-size=<initial_size> test-grid
```

Now you can start provisioning nodes to Packet. Issue the following command (with the proper options) as many times as desired:

```
$ kontena packet node create \
  --token <packet_api_token> \
  --project <project_id> \
  --type baremetal_0
```

**Note!** While Kontena will work with just a single Kontena Node, it is recommended to have at least three Kontena Nodes provisioned in a Grid.

After creating Nodes, you can verify that they have joined a Grid:

```
$ kontena node list
```

## Packet Command Reference

#### Create Master

```
Usage:
    kontena packet master create [OPTIONS]

Options:
    --token TOKEN                 Packet API token
    --project PROJECT ID          Packet project id
    --ssl-cert PATH               SSL certificate file (optional)
    --type TYPE                   Server type (baremetal_0, baremetal_1, ..) (default: "baremetal_0")
    --facility FACILITY CODE      Facility (default: "ams1")
    --billing BILLING             Billing cycle (default: "hourly")
    --ssh-key PATH                Path to ssh public key (optional)
    --vault-secret VAULT_SECRET   Secret key for Vault (optional)
    --vault-iv VAULT_IV           Initialization vector for Vault (optional)
    --mongodb-uri URI             External MongoDB uri (optional)
    --version VERSION             Define installed Kontena version (default: "latest")
```

#### Create Node

```
Usage:
    kontena packet node create [OPTIONS] [NAME]

Parameters:
    [NAME]                        Node name

Options:
    --grid GRID                   Specify grid to use
    --token TOKEN                 Packet API token
    --project PROJECT ID          Packet project id
    --type TYPE                   Server type (baremetal_0, baremetal_1, ..) (default: "baremetal_0")
    --facility FACILITY CODE      Facility (default: "ams1")
    --billing BILLING             Billing cycle (default: "hourly")
    --ssh-key PATH                Path to ssh public key (optional)
    --version VERSION             Define installed Kontena version (default: "latest")
```

#### Restart Node

```
Usage:
    kontena packet node restart [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
    --token TOKEN                 Packet API token
    --project PROJECT ID          Packet project id
```

#### Terminate Node

```
Usage:
    kontena packet node terminate [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
    --token TOKEN                 Packet API token
    --project PROJECT ID          Packet project id
```
