---
title: AWS EC2
---

# Running Kontena on AWS EC2

- [Prerequisites](aws-ec2.md#prerequisites)
- [Installing AWS Plugin](aws-ec2.md#installing-kontena-aws-plugin)
- [Installing Kontena Master](aws-ec2.md#installing-kontena-master)
- [Installing Kontena Nodes](aws-ec2.md#installing-kontena-nodes)
- [AWS Plugin Command Reference](aws-ec2.md#aws-plugin-command-reference)

## Prerequisites

- [Kontena CLI](cli.md)
- AWS Account. Visit [http://aws.amazon.com](http://aws.amazon.com) to get started
- AWS [instance profile and role](http://docs.aws.amazon.com/IAM/latest/UserGuide/instance-profiles.html) with full EC2 access

## Installing Kontena AWS Plugin

```
$ kontena plugin install aws
```

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master to AWS EC2 can be done by issuing the following command:

```
$ kontena aws master create \
  --access-key <aws_master_key> \
  --secret-key <aws_secret_key> \
  --key-pair <aws_key_pair_name> \
  --type m3.medium \
  --storage 100 \
  --region eu-west-1
```

After Kontena Master has provisioned, you will be automatically authenticated as the Kontena Master internal administrator and the default Grid 'test' is set as the current Grid.

## Installing Kontena Nodes

Before you can start provisioning Nodes you must first switch the CLI scope to a Grid. A Grid can be thought of as a cluster of Nodes that can have members from multiple clouds and/or regions.

Switch to an existing Grid using the following command:

```
$ kontena grid use <grid_name>
```

Or create a new Grid using the command:

```
$ kontena grid create --initial-size=<initial_node_count> aws-grid
```

Now you can start provisioning AWS EC2 nodes. Issue the following command (with the proper options) as many times as desired:

```
$ kontena aws node create \
  --access-key <aws_master_key> \
  --secret-key <aws_secret_key> \
  --key-pair <aws_key_pair_name> \
  --type m4.medium \
  --storage 100 \
  --zone a \
  --region eu-west-1
```

## AWS Plugin Command Reference

#### Create Master

```
Usage:
    kontena aws master create [OPTIONS]

Options:
    --access-key ACCESS_KEY       AWS access key ID
    --secret-key SECRET_KEY       AWS secret key
    --key-pair KEY_PAIR           EC2 key pair name
    --ssl-cert SSL CERT           SSL certificate file (default: generate self-signed cert)
    --region REGION               EC2 Region (default: "eu-west-1")
    --zone ZONE                   EC2 Availability Zone (default: "a")
    --vpc-id VPC ID               Virtual Private Cloud (VPC) ID (default: default vpc)
    --subnet-id SUBNET ID         VPC option to specify subnet to launch instance into (default: first subnet from vpc/az)
    --type SIZE                   Instance type (default: "t2.small")
    --storage STORAGE             Storage size (GiB) (default: "30")
    --vault-secret VAULT_SECRET   Secret key for Vault (default: generate random secret)
    --vault-iv VAULT_IV           Initialization vector for Vault (default: generate random iv)
    --mongodb-uri URI             External MongoDB uri (optional)
    --version VERSION             Define installed Kontena version (default: "latest")
    --associate-public-ip-address Whether to associated public IP in case the VPC defaults to not doing it (default: true)
    --security-groups SECURITY_GROUPS Comma separated list of security groups (names) where the new instance will be attached (default: create 'kontena_master' group if not already existing)
```

#### Create Node

```
Usage:
    kontena aws node create [OPTIONS] [NAME]

Parameters:
    [NAME]                        Node name

Options:
    --grid GRID                   Specify grid to use
    --access-key ACCESS_KEY       AWS access key ID
    --secret-key SECRET_KEY       AWS secret key
    --key-pair KEY_PAIR           EC2 Key Pair
    --region REGION               EC2 Region (default: "eu-west-1")
    --zone ZONE                   EC2 Availability Zone (default: "a")
    --vpc-id VPC ID               Virtual Private Cloud (VPC) ID (default: default vpc)
    --subnet-id SUBNET ID         VPC option to specify subnet to launch instance into (default: first subnet in vpc/az)
    --type SIZE                   Instance type (default: "t2.small")
    --storage STORAGE             Storage size (GiB) (default: "30")
    --version VERSION             Define installed Kontena version (default: "latest")
    --associate-public-ip-address Whether to associated public IP in case the VPC defaults to not doing it (default: true)
    --security-groups SECURITY GROUPS Comma-separated list of security groups (names) where the new instance will be attached (default: create grid specific group if not already existing)
```


#### Restart Node

```
Usage:
    kontena aws node restart [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
    --access-key ACCESS_KEY       AWS access key ID
    --secret-key SECRET_KEY       AWS secret key
    --region REGION               EC2 Region (default: "eu-west-1")
```

#### Terminate Node

```
Usage:
    kontena aws node terminate [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
    --access-key ACCESS_KEY       AWS access key ID
    --secret-key SECRET_KEY       AWS secret key
    --region REGION               EC2 Region (default: "eu-west-1")
```
