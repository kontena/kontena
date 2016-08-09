---
title: Running Kontena on AWS EC2
toc_order: 1
---

# Running Kontena on AWS EC2

- [Prerequisities](aws-ec2#prerequisities)
- [Installing AWS Plugin](aws-ec2#installing-kontena-aws-plugin)
- [Installing Kontena Master](aws-ec2#installing-kontena-master)
- [Installing Kontena Nodes](aws-ec2#installing-kontena-nodes)
- [AWS Command Reference](aws-ec2#aws-command-reference)

## Prerequisities

- Kontena Account
- AWS Account. Visit [http://aws.amazon.com](http://aws.amazon.com) to get started
- AWS [instance profile and role](http://docs.aws.amazon.com/IAM/latest/UserGuide/instance-profiles.html) with full EC2 access

## Installing Kontena AWS Plugin

```
$ kontena plugin install aws
```

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master to AWS EC2 can be done by just issuing following command:

```
$ kontena aws master create \
  --access-key <aws_master_key> \
  --secret-key <aws_secret_key> \
  --key-pair <aws_key_pair_name> \
  --type m3.medium \
  --storage 100 \
  --region eu-west-1
```

After Kontena Master has provisioned you can connect to it by issuing login command. First user to login will be given master admin rights.

```
$ kontena login --name aws-master https://<master_ip>/
```

## Installing Kontena Nodes

Before you can start provision nodes you must first switch cli scope to a grid. Grid can be thought as a cluster of nodes that can have members from multiple clouds and/or regions.

Switch to existing grid using following command:

```
$ kontena grid use <grid_name>
```

Or create a new grid using command:

```
$ kontena grid create --initial-size=<initial_node_count> aws-grid
```

Now you can start provision AWS EC2 nodes. Issue following command (with right options) as many times as desired:

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

## AWS Command Reference

#### Create Master

```
Usage:
    kontena master aws create [OPTIONS]

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
    --version VERSION             Define installed Kontena version (default: "latest")
    --auth-provider-url AUTH_PROVIDER_URL Define authentication provider url (optional)
    --associate-public-ip-address Flag to associate public IP address in VPC that does not do it automatically
    --security-groups             Comma separated list of security group names to which the new master will be attached
```

#### Create Node

```
Usage:
    kontena aws node create [OPTIONS]

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
    --associate-public-ip-address Flag to associate public IP address in VPC that does not do it automatically
    --security-groups             Comma separated list of security group names to which the new master will be attached
```
