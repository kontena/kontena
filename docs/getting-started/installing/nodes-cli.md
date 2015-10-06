---
title: Nodes (with Kontena CLI)
toc_order: 3
---

# Installing Kontena Nodes with Kontena CLI

Kontena CLI may be used to provision new Kontena Nodes based on [CoreOS](https://coreos.com/using-coreos/), fully configured and ready for action! At the moment, you can provision Nodes to following platforms:

* Vagrant (for local testing)
* DigitalOcean
* AWS

We are adding support for other platforms gradually based on your requests. If you'd like to see support for the platform you are using, please [post your request](https://github.com/kontena/kontena/issues) as an issue to our GitHub repository.

## Vagrant

```
Usage:
    kontena node vagrant create [OPTIONS] [NAME]

Parameters:
    [NAME]                        Node name

Options:
    --memory MEMORY               How much memory node has (default: "1024")
    --version VERSION             Define installed Kontena version (default: "latest")
    -h, --help                    print help

```

## Digital Ocean

```
Usage:
    kontena node digitalocean create [OPTIONS] [NAME]

Parameters:
    [NAME]                        Node name

Options:
    --token TOKEN                 DigitalOcean API token
    --ssh-key SSH_KEY             Path to ssh public key
    --size SIZE                   Droplet size (default: "1gb")
    --region REGION               Region (default: "ams2")
    --version VERSION             Define installed Kontena version (default: "latest")
    -h, --help                    print help
```

## AWS
```
Usage:
    kontena node aws create [OPTIONS]

Options:
    --name NAME                   Node name
    --access-key ACCESS_KEY       AWS access key ID
    --secret-key SECRET_KEY       AWS secret key
    --region REGION               EC2 Region (default: "eu-west-1")
    --zone ZONE                   EC2 Availability Zone (default: "a")
    --vpc-id VPC ID               Virtual Private Cloud (VPC) ID
    --subnet-id SUBNET ID         VPC option to specify subnet to launch instance into
    --key-pair KEY_PAIR           EC2 Key Pair
    --type SIZE                   Instance type (default: "t2.small")
    --storage STORAGE             Storage size (GiB) (default: "30")
    --version VERSION             Define installed Kontena version (default: "latest")
    -h, --help                    print help
``