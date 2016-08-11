---
title: UpCloud
---

# Running Kontena on UpCloud

- [Prerequisities](upcloud#prerequisities)
- [Installing UpCloud Plugin](upcloud#installing-kontena-upcloud-plugin)
- [Installing Kontena Master](upcloud#installing-kontena-master)
- [Installing Kontena Nodes](upcloud#installing-kontena-nodes)
- [UpCloud Plugin Command Reference](upcloud#upcloud-plugin-command-reference)

## Prerequisities

- Kontena Account
- UpCloud Account. Visit [https://www.upcloud.com/kontena/](https://www.upcloud.com/kontena/) to get started

## Installing Kontena UpCloud Plugin

```
$ kontena plugin install upcloud
```

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master to UpCloud can be done by just issuing following command:

```
$ kontena upcloud master create \
  --username <upcloud-username> \
  --password <upcloud-password> \
  --ssh-key <path-to-ssh-public-key>
```

After Kontena Master has provisioned you can connect to it by issuing login command. First user to login will be given master admin rights.

```
$ kontena login --name upcloud-master https://<master_ip>/
```

## Installing Kontena Nodes

Before you can start provision nodes you must first switch cli scope to a grid. Grid can be thought as a cluster of nodes that can have members from multiple clouds and/or regions.

Switch to existing grid using following command:

```
$ kontena grid use <grid_name>
```

Or create a new grid using command:

```
$ kontena grid create --initial-size=<initial_size> test-grid
```

Now you can start provision nodes to Packet. Issue following command (with right options) as many times as desired:

```
$ kontena upcloud node create \
  --username <upcloud-username> \
  --password <upcloud-password> \
  --ssh-key <path-to-ssh-public-key>
```

**Note!** While Kontena works ok even with just single Kontena Node, it is recommended to have at least 3 Kontena Nodes provisioned in a Grid.

After creating nodes, you can verify that they have joined Grid:

```
$ kontena node list
```

## UpCloud Plugin Command Reference

#### Create Master

```
Usage:
    kontena upcloud master create [OPTIONS]

Options:
    --username USER               Upcloud username
    --password PASS               Upcloud password
    --ssh-key SSH_KEY             Path to ssh public key
    --ssl-cert SSL CERT           SSL certificate file (optional)
    --plan PLAN                   Server plan (default: "1xCPU-1GB")
    --zone ZONE                   Zone (default: "fi-hel1")
    --vault-secret VAULT_SECRET   Secret key for Vault (optional)
    --vault-iv VAULT_IV           Initialization vector for Vault (optional)
    --mongodb-uri URI             External MongoDB uri (optional)
    --version VERSION             Define installed Kontena version (default: "latest")
    --auth-provider-url AUTH_PROVIDER_URL Define authentication provider url

Note: The username for ssh access is "root"
```

#### Create Node

```
Usage:
    kontena upcloud node create [OPTIONS] [NAME]

Parameters:
    [NAME]                        Node name

Options:
    --grid GRID                   Specify grid to use
    --username USER               Upcloud username
    --password PASS               Upcloud password
    --ssh-key SSH_KEY             Path to ssh public key
    --plan PLAN                   Server size (default: "1xCPU-1GB")
    --zone ZONE                   Zone (default: "fi-hel1")
    --version VERSION             Define installed Kontena version (default: "latest")

Note: The username for ssh access is "root"
```

#### Restart Node

```
Usage:
    kontena upcloud node restart [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
    --username USER               Upcloud username
    --password PASS               Upcloud password
```

#### Terminate Node

```
Usage:
    kontena upcloud node terminate [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
    --username USER               Upcloud username
    --password PASS               Upcloud password
```
