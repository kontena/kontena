---
title: Nodes (with Kontena CLI)
toc_order: 3
---

# Installing Kontena Nodes with Kontena CLI

Kontena CLI may be used to provision new Kontena Nodes based on [CoreOS](https://coreos.com/using-coreos/), fully configured and ready for action! At the moment, you can provision Nodes to following platforms:

* Vagrant (for local testing)
* DigitalOcean

We are adding support for other platforms gradually based on your requests. If you'd like to see support for the platform you are using, please [post your request](https://github.com/kontena/kontena/issues) as an issue to our GitHub repository.

## Vagrant

```
Usage:
    kontena node vagrant create [OPTIONS]

Options:
    --name NAME                   Node name
    --memory MEMORY               How much memory node has (default: 1024)
    --version VERSION             Define installed Kontena version (default: latest)
```

## Digital Ocean

```
Usage:
    kontena node digitalocean create [OPTIONS]

Options:
    --name NAME                   Node name
    --token TOKEN                 DigitalOcean API token
    --ssh-key SSH_KEY             Path to ssh public key
    --size SIZE                   Droplet size (default: "1gb")
    --region REGION               Region (default: "ams2")
    --version VERSION             Define installed Kontena version (default: latest)
```
