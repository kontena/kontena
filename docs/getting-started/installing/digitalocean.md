---
title: DigitalOcean
---

# Running Kontena on DigitalOcean

- [Prerequisities](digitalocean#prerequisities)
- [Installing DigitalOcean Plugin](digitalocean#installing-kontena-digitalocean-plugin)
- [Installing Kontena Master](digitalocean#installing-kontena-master)
- [Installing Kontena Nodes](digitalocean#installing-kontena-nodes)
- [DigitalOcean Plugin Command Reference](digitalocean#digitalocean-plugin-command-reference)

## Prerequisities

- Kontena Account
- DigitalOcean Account. Visit [https://www.digitalocean.com/](https://www.digitalocean.com/) to get started
- DigitalOcean API token. Visit [https://cloud.digitalocean.com/settings/api/tokens](https://cloud.digitalocean.com/settings/api/tokens)

## Installing Kontena DigitalOcean Plugin

```
$ kontena plugin install digitalocean
```

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master to DigitalOcean can be done by just issuing following command:

```
$ kontena digitalocean master create \
  --token <do_api_token> \
  --ssh-key ~/.ssh/id_rsa.pub \
  --size 1gb \
  --region am2
```

After Kontena Master has provisioned you can connect to it by issuing login command. First user to login will be given master admin rights.

```
$ kontena login --name do-master https://<master_ip>/
```

## Installing Kontena Nodes

Before you can start provision nodes you must first switch cli scope to a grid. Grid can be thought as a cluster of nodes that can have members from multiple clouds and/or regions.

Switch to existing grid using following command:

```
$ kontena grid use <grid_name>
```

Or create a new grid using command:

```
$ kontena grid create --initial-size=<initial_size> do-grid
```

Now you can start provision nodes to DigitalOcean. Issue following command (with right options) as many times as desired:

```
$ kontena digitalocean node create \
  --token <do_api_token> \
  --ssh-key ~/.ssh/id_rsa.pub \
  --size 1gb \
  --region am2
```

**Note!** While Kontena works ok even with just single Kontena Node, it is recommended to have at least 3 Kontena Nodes provisioned in a Grid.

After creating nodes, you can verify that they have joined Grid:

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
    --auth-provider-url AUTH_PROVIDER_URL Define authentication provider url
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
