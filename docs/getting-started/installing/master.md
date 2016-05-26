---
title: Installing Kontena Master
toc_order: 1
---

# Installing Kontena Master

## Installing with Kontena CLI

Kontena CLI may be used to provision Kontena Master based on [CoreOS](https://coreos.com/using-coreos/), fully configured and ready for action! At the moment, you can provision Kontena Master to following platforms:

* [Amazon AWS](master#amazon-aws)
* [Microsoft Azure](master#microsoft-azure)
* [DigitalOcean](master#digitalocean)
* [Packet](master#packet)
* [Vagrant (local environment)](master#vagrant)
* [Manual Install](master#manual-install)
  * [CoreOS](master#coreos)
  * [Ubuntu](master#ubuntu-14-04)

We are adding support for other platforms gradually based on your requests. If you'd like to see support for the platform you are using, please [post your request](https://github.com/kontena/kontena/issues) as an issue to our GitHub repository.

### Amazon AWS

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
```

### Microsoft Azure

```
Usage:
    kontena master azure create [OPTIONS]

Options:
    --subscription-id SUBSCRIPTION ID Azure subscription id
    --subscription-cert CERTIFICATE Path to Azure management certificate
    --size SIZE                   SIZE (default: "Small")
    --network NETWORK             Virtual Network name
    --subnet SUBNET               Subnet name
    --ssh-key SSH KEY             SSH private key file
    --password PASSWORD           Password
    --location LOCATION           Location (default: "West Europe")
    --ssl-cert SSL CERT           SSL certificate file
    --auth-provider-url AUTH_PROVIDER_URL Define authentication provider url
    --vault-secret VAULT_SECRET   Secret key for Vault
    --vault-iv VAULT_IV           Initialization vector for Vault
    --version VERSION             Define installed Kontena version (default: "latest")
```

### DigitalOcean

```
Usage:
    kontena master digitalocean create [OPTIONS]

Options:
    --token TOKEN                 DigitalOcean API token
    --ssh-key SSH_KEY             Path to ssh public key
    --ssl-cert SSL CERT           SSL certificate file
    --size SIZE                   Droplet size (default: "1gb")
    --region REGION               Region (default: "ams2")
    --vault-secret VAULT_SECRET   Secret key for Vault
    --vault-iv VAULT_IV           Initialization vector for Vault
    --version VERSION             Define installed Kontena version (default: "latest")
    --auth-provider-url AUTH_PROVIDER_URL Define authentication provider url
```

### Packet
Usage:
    kontena master packet create [OPTIONS]

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
    --auth-provider-url AUTH_PROVIDER_URL Define authentication provider url
```

### Vagrant

```
Usage:
    kontena master vagrant create [OPTIONS]

Options:
    --memory MEMORY               How much memory node has (default: "512")
    --vault-secret VAULT_SECRET   Secret key for Vault
    --vault-iv VAULT_IV           Initialization vector for Vault
    --version VERSION             Define installed Kontena version (default: "latest")
    --auth-provider-url AUTH_PROVIDER_URL Define authentication provider url
```

## Manual Install

Kontena Master can be installed manually to almost any linux distribution. Below you can find examples for CoreOS and Ubuntu.

### CoreOS

Example cloud-config:

```yaml
#cloud-config
write_files:
  - path: /etc/kontena-server.env
    permissions: 0600
    owner: root
    content: |
      KONTENA_VERSION=latest
      KONTENA_VAULT_KEY=<your vault_key>
      KONTENA_VAULT_IV=<your vault_iv>
      SSL_CERT="/etc/kontena-server.pem"

  - path: /etc/kontena-server.pem
    permissions: 0600
    owner: root
    content: |
      <your ssl_certificate>

  - path: /opt/bin/kontena-haproxy.sh
    permissions: 0755
    owner: root
    content: |
      #!/bin/sh
      if [ -n "$SSL_CERT" ]; then
        SSL_CERT=$(awk 1 ORS='\\n' $SSL_CERT)
      else
        SSL_CERT="**None**"
      fi
      /usr/bin/docker run --name=kontena-server-haproxy \
        --link kontena-server-api:kontena-server-api \
        -e SSL_CERT="$SSL_CERT" -e BACKEND_PORT=9292 \
        -p 80:80 -p 443:443 kontena/haproxy:latest
coreos:
  units:
    - name: kontena-server-mongo.service
      command: start
      enable: true
      content: |
        [Unit]
        Description=kontena-server-mongo
        After=network-online.target
        After=docker.service
        Description=Kontena Server MongoDB
        Documentation=http://www.mongodb.org/
        Requires=network-online.target
        Requires=docker.service

        [Service]
        Restart=always
        RestartSec=5
        ExecStartPre=/usr/bin/docker pull mongo:3.0
        ExecStartPre=-/usr/bin/docker create --name=kontena-server-mongo-data mongo:3.0
        ExecStartPre=-/usr/bin/docker stop kontena-server-mongo
        ExecStartPre=-/usr/bin/docker rm kontena-server-mongo
        ExecStart=/usr/bin/docker run --name=kontena-server-mongo \
            --volumes-from=kontena-server-mongo-data \
            mongo:3.0 mongod --smallfiles

    - name: kontena-server-api.service
      command: start
      enable: true
      content: |
        [Unit]
        Description=kontena-server-api
        After=network-online.target
        After=docker.service
        Description=Kontena Agent
        Documentation=http://www.kontena.io/
        Requires=network-online.target
        Requires=docker.service

        [Service]
        Restart=always
        RestartSec=5
        EnvironmentFile=/etc/kontena-server.env
        ExecStartPre=-/usr/bin/docker stop kontena-server-api
        ExecStartPre=-/usr/bin/docker rm kontena-server-api
        ExecStartPre=/usr/bin/docker pull kontena/server:${KONTENA_VERSION}
        ExecStart=/usr/bin/docker run --name kontena-server-api \
            --link kontena-server-mongo:mongodb \
            -e MONGODB_URI=mongodb://mongodb:27017/kontena_server \
            -e VAULT_KEY=${KONTENA_VAULT_KEY} -e VAULT_IV=${KONTENA_VAULT_IV} \
            kontena/server:${KONTENA_VERSION}

    - name: kontena-server-haproxy.service
      command: start
      enable: true
      content: |
        [Unit]
        Description=kontena-server-haproxy
        After=network-online.target
        After=docker.service
        Description=Kontena Server HAProxy
        Documentation=http://www.kontena.io/
        Requires=network-online.target
        Requires=docker.service

        [Service]
        Restart=always
        RestartSec=5
        EnvironmentFile=/etc/kontena-server.env
        ExecStartPre=-/usr/bin/docker stop kontena-server-haproxy
        ExecStartPre=-/usr/bin/docker rm kontena-server-haproxy
        ExecStartPre=/usr/bin/docker pull kontena/haproxy:latest
        ExecStart=/opt/bin/kontena-haproxy.sh
```

`KONTENA_VAULT_KEY` & `KONTENA_VAULT_IV` should be random strings. They can be generated from bash:

```
$ cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1
```

The SSL certificate specified is a pem file, containing a public certificate followed by a private key (public certificate must be put before the private key, order matters).

### Ubuntu 14.04

#### Install Kontena Ubuntu packages

```sh
$ wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
$ echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get update
$ sudo apt-get install kontena-server
```

#### Setup ssl certificate

```sh
$ sudo vim /etc/default/kontena-server-haproxy

# HAProxy SSL certificate
SSL_CERT=/path/to/certificate.pem
```

#### Start Kontena server

```sh
$ sudo start kontena-server-api
```
