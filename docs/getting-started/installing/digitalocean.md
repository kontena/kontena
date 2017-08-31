---
title: DigitalOcean
---

# Running Kontena on DigitalOcean

- [Prerequisites](digitalocean.md#prerequisites)
- [Installing DigitalOcean Plugin](digitalocean.md#installing-kontena-digitalocean-plugin)
- [Installing Kontena Master](digitalocean.md#installing-kontena-master)
- [Installing Kontena Nodes](digitalocean.md#installing-kontena-nodes)
- [DigitalOcean Plugin Command Reference](digitalocean.md#digitalocean-plugin-command-reference)

## Caveats

### Cannot update `cloud-config.yml` after node creation

The Kontena DigitalOcean plugin creates CoreOS virtual machines for the master and nodes. CoreOS machines are configured using a configuration file called `cloud-config.yml`. On DigitalOcean, this configuration file is stored in [instance metadata](https://www.digitalocean.com/community/tutorials/an-introduction-to-droplet-metadata).

DigitalOcean [provides no way to update instance metadata](https://www.digitalocean.com/community/questions/how-to-update-coreos-cloud-config), including `cloud-config.yml`, after the instance has been created. This means that if you want to, for example, update SSH keys or set `sysctl`s in a persistent fashion, you will need to create new nodes and decommission old ones.

## Prerequisites

- [Kontena CLI](cli.md)
- DigitalOcean Account. Visit [https://www.digitalocean.com/](https://www.digitalocean.com/) to get started
- DigitalOcean API token. Visit [https://cloud.digitalocean.com/settings/api/tokens](https://cloud.digitalocean.com/settings/api/tokens)

## Installing Kontena DigitalOcean Plugin

```
$ kontena plugin install digitalocean
```

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Kontena Master can be installed on DigitalOcean by issuing the following command:

```
$ kontena digitalocean master create \
  --token <do_api_token> \
  --ssh-key ~/.ssh/id_rsa.pub \
  --size 1gb \
  --region am2
```

After the Kontena Master has been provisioned you will be automatically authenticated as the Kontena Master internal administrator and the default Grid 'test' is set as the current Grid.

## Installing Kontena Nodes

Before you can start provisioning Nodes you must first switch the CLI scope to a Grid. A Grid can be thought of as a cluster of Nodes that can have members from multiple clouds and/or regions.

Switch to an existing Grid using the following command:

```
$ kontena grid use <grid_name>
```

Or create a new Grid using the command:

```
$ kontena grid create --initial-size=<initial_size> do-grid
```

Now you can start provisioning nodes on DigitalOcean. Issue the following command (with the proper options) as many times as desired:

```
$ kontena digitalocean node create \
  --token <do_api_token> \
  --ssh-key ~/.ssh/id_rsa.pub \
  --size 1gb \
  --region am2
```

**Note!** While Kontena will work with just a single Kontena Node, it is recommended to have at least three Kontena Nodes provisioned in a Grid.

After creating Nodes, you can verify that they have joined a Grid:

```
$ kontena node list
```

## DigitalOcean Plugin Command Reference

#### Create Master

```
Usage:
    kontena digitalocean master create [OPTIONS]

Options:
    --token TOKEN                 DigitalOcean API token
    --ssh-key SSH_KEY             Path to ssh public key (default: "~/.ssh/id_rsa.pub")
    --ssl-cert SSL CERT           SSL certificate file  (optional)
    --size SIZE                   Droplet size (default: "1gb")
    --region REGION               Region (default: "ams2")
    --vault-secret VAULT_SECRET   Secret key for Vault (optional)
    --vault-iv VAULT_IV           Initialization vector for Vault (optional)
    --mongodb-uri URI             External MongoDB uri (optional)
    --version VERSION             Define installed Kontena version (default: "latest")
```

#### Create Node

```
Usage:
    kontena digitalocean node create [OPTIONS] [NAME]

Parameters:
    [NAME]                        Node name

Options:
    --grid GRID                   Specify grid to use
    --token TOKEN                 DigitalOcean API token
    --ssh-key SSH_KEY             Path to ssh public key (default: "~/.ssh/id_rsa.pub")
    --size SIZE                   Droplet size (default: "1gb")
    --region REGION               Region (default: "ams2")
    --version VERSION             Define installed Kontena version (default: "latest")
```

#### Restart Node

```
Usage:
    kontena digitalocean node restart [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
    --token TOKEN                 DigitalOcean API token
```


### Terminate Node

```
Usage:
    kontena digitalocean node terminate [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
    --token TOKEN                 DigitalOcean API token
```
