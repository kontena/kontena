---
title: Image Registry
toc_order: 5
---

# Kontena Image Registry

Kontena has built-in support for creating private Image Registry. The Image Registry may be used to store Docker images used by your own application. Kontena's Image Registry is running in the same infrastructure and private network with your Nodes. Therefore, the access to Kontena's Image Registry is not open for public and may be accessed only with [VPN access](vpn-access.md), ensuring you'll have total control over the access control, security and distribution of your images. Kontena Image Registry is based on [Docker Image Registry](https://docs.docker.com/registry/).

Kontena may be used with any Docker Image Registry. Users looking for a zero maintenance, ready-to-go solution are encouraged to check [Docker Hub](https://hub.docker.com/account/signup/) or [Quay](https://quay.io/) who provide a hosted Registry, plus some advanced features.

You should use the Kontena's built-in Image Registry if you want to:

* Have total control where your images are being stored
* Fully own your images distribution pipeline
* Ensure access control and security for your own Docker images


## Using Image Registry

### Create Image Registry Service

Create using local volume storage backend:

```
$ kontena registry create
```

Create using Amazon S3 storage backend:

```
$ kontena registry create --s3-access-key=<access_key> --s3-secret-key=<secret_key> --s3-bucket=<bucket_name> --s3-region=<optional_aws_region>
```

Create using Azure storage backend:

```
$ kontena registry create --azure-account-name=<account_name> --azure-account-key=<account_key> --azure-container-name=<container_name>
```

### Accessing Image Registry

Before you can push images to registry, you should setup Kontena VPN service. In addition to VPN, you must set `--insecure-registry=registry.kontena.local` to your local docker daemon opts.

Building and pushing image to registry:

```
$ docker build -t registry.kontena.local/myimage:mytag .
$ docker push registry.kontena.local/myimage:mytag
```

Deploying image from registry:

```
$ kontena service create myservice registry.kontena.local/myimage:mytag
$ kontena service deploy myservice
```
