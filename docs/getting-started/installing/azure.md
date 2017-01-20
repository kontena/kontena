---
title: Azure
---

# Running Kontena on Azure (Classic)

- [Prerequisities](azure.md#prerequisities)
- [Installing Azure Plugin](azure.md#installing-kontena-aws-plugin)
- [Installing Kontena Master](azure.md#installing-kontena-master)
- [Installing Kontena Nodes](azure.md#installing-kontena-nodes)
- [Azure Plugin Command Reference](azure.md#azure-plugin-command-reference)

## Prerequisites

- [Kontena CLI](cli.md)
- Azure Account

## Installing Kontena Azure Plugin

```
$ kontena plugin install azure
```

## Creating Azure Management Certificate

You can use OpenSSL to create your management certificates. Two certificates are necessary: One for the server (a .cer file) and one for the client (a .pem file). To create the .pem file, execute this command:

```
openssl req -x509 -nodes -days 365 -newkey rsa:1024 -keyout mycert.pem -out mycert.pem
```

To create the .cer certificate, execute this command:

```
openssl x509 -inform pem -in mycert.pem -outform der -out mycert.cer
```

For more information about Azure certificates, see [Certificates Overview for Azure Cloud Services](https://azure.microsoft.com/en-us/documentation/articles/cloud-services-certs-create/). For a complete description of OpenSSL parameters, see the documentation at http://www.openssl.org/docs/apps/openssl.html.

After you have created these files, you will need to upload the .cer file to Azure via the "Upload" action of the "Settings" tab of the [Azure classic portal](https://manage.windowsazure.com/), and you will need to make note of where you saved the .pem file.

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master to Azure can be done by issuing the following command:

```
$ kontena azure master create \
  --subscription-id <subscription-id> \
  --subscription-cert <subscription-cert> \
  --ssh-key <path-to-ssh-private-key>
```

After Kontena Master has been provisioned, you will be automatically authenticated as the Kontena Master internal administrator and the default Grid 'test' is set as the current Grid.

## Installing Kontena Nodes

Before you can start provisioning Nodes you must first switch the CLI scope to a Grid. A Grid can be thought of as a cluster of Nodes that can have members from multiple clouds and/or regions.

Switch to an existing Grid using the following command:

```
$ kontena grid use <grid_name>
```

Or create a new Grid using the command:

```
$ kontena grid create --initial-size=<initial_node_count> test-grid
```

Now you can start provisioning Nodes on Azure. Issue the following command (with the proper options) as many times as desired:

```
$ kontena azure node create \
  --subscription-id <subscription-id> \
  --subscription-cert <subscription-cert> \
  --ssh-key <path-to-ssh-private-key>
```

## Azure Plugin Command Reference

#### Create Master

```
Usage:
    kontena azure master create [OPTIONS]

Options:
    --subscription-id SUBSCRIPTION ID Azure subscription id
    --subscription-cert CERTIFICATE Path to Azure management certificate
    --size SIZE                   SIZE (default: "Small")
    --network NETWORK             Virtual Network name
    --subnet SUBNET               Subnet name
    --ssh-key SSH KEY             SSH private key file
    --location LOCATION           Location (default: "West Europe")
    --ssl-cert SSL CERT           SSL certificate file
    --vault-secret VAULT_SECRET   Secret key for Vault
    --vault-iv VAULT_IV           Initialization vector for Vault
    --version VERSION             Define installed Kontena version (default: "latest")
```

#### Create Node

```
Usage:
    kontena azure node create [OPTIONS] [NAME]

Parameters:
    [NAME]                        Node name

Options:
    --grid GRID                   Specify grid to use
    --subscription-id SUBSCRIPTION ID Azure subscription id
    --subscription-cert CERTIFICATE Path to Azure management certificate
    --size SIZE                   SIZE (default: "Small")
    --network NETWORK             Virtual Network name
    --subnet SUBNET               Subnet name
    --ssh-key SSH KEY             SSH private key file
    --location LOCATION           Location (default: "West Europe")
    --version VERSION             Define installed Kontena version (default: "latest")
```

#### Restart Node

```
Usage:
    kontena azure node restart [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
    --subscription-id SUBSCRIPTION ID Azure subscription id
    --subscription-cert CERTIFICATE Path to Azure management certificate
```

#### Terminate Node

```
Usage:
    kontena azure node terminate [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
    --subscription-id SUBSCRIPTION ID Azure subscription id
    --subscription-cert CERTIFICATE Path to Azure management certificate
```
