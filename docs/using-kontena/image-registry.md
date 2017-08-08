---
title: Image Registry
---

# Kontena Image Registry

Kontena has built-in support for creating a private Image Registry. The Image Registry may be used to store Docker images used by your own application. Kontena's Image Registry runs on the same infrastructure and private network as your Nodes. Therefore, access to Kontena's Image Registry is not open publicly and may be accessed only by using [VPN access](vpn-access.md). This isolation ensures that you will have total control over the access control, security and distribution of your images. Kontena Image Registry is based on [Docker Image Registry](https://docs.docker.com/registry/).

Kontena may be used with any Docker Image Registry. Users looking for a zero-maintenance, ready-to-go solution are encouraged to consider [Docker Hub](https://hub.docker.com/account/signup/) or [Quay](https://quay.io/). Both of these services provide a hosted registry, as well as some advanced features.

You should use Kontena's built-in Image Registry if you want to:

* Have total control over where your images are being stored
* Fully own your images' distribution pipeline
* Ensure access control and security for your own Docker images

## Using Image Registry

* [Create Image Registry Service](image-registry.md#create-image-registry-service)
  * [Local Storage Backend](image-registry.md#local-storage-backend)
  * [Amazon S3 Storage Backend](image-registry.md#amazon-s3-storage-backend)
  * [Azure Storage Backend](image-registry.md#azure-storage-backend)
* [Accessing Image Registry](image-registry.md#accessing-image-registry)
* [TLS/SSL](image-registry.md#tlsssl)
* [Authentication](image-registry.md#authentication)

### Create Image Registry Service

#### Local Storage Backend

```
$ kontena registry create
```

#### Amazon S3 Storage Backend

Write Amazon S3 access keys to Kontena Vault:

```
$ kontena vault write REGISTRY_STORAGE_S3_ACCESSKEY <access_key>
$ kontena vault write REGISTRY_STORAGE_S3_SECRETKEY <secret_key>
```

Create registry service:

```
$ kontena registry create --s3-bucket=<bucket_name> --s3-region=<optional_aws_region> --s3-v4auth
```

#### Azure storage backend

Write Azure account key to Kontena Vault:

```
$ kontena vault write REGISTRY_STORAGE_AZURE_ACCOUNTKEY <azure_account_key>
```

Create registry service:

```
$ kontena registry create --azure-account-name=<account_name> --azure-container-name=<container_name>
```

### Accessing Image Registry

Before you can push images to the registry, you should set up the Kontena VPN service. In addition, you must set `--insecure-registry=registry.<grid_name>.kontena.local` in your local Docker daemon configuration.

Building and pushing an image to the registry:

```
$ docker build -t registry.<grid_name>.kontena.local/myimage:mytag .
$ docker push registry.<grid_name>.kontena.local/myimage:mytag
```

Deploying an image from the registry:

```
$ kontena service create myservice registry.<grid_name>.kontena.local/myimage:mytag
$ kontena service deploy myservice
```

### TLS/SSL

Generate your own certificate:

```
$ openssl req -x509 -newkey rsa:2048 -keyout registry_key.pem -out registry_ca.pem -days 1080 -nodes -subj '/CN=registry.<grid_name>.kontena.local/O=My Company Name LTD./C=US'
```

Write key and certificate to Kontena Vault:

```
$ kontena vault write REGISTRY_HTTP_TLS_KEY "$(cat registry_key.pem)"
$ kontena vault write REGISTRY_HTTP_TLS_CERTIFICATE "$(cat registry_ca.pem)"
```

Redeploy Kontena Image Registry:

```
$ kontena service deploy --force registry/api
```

Then you have to instruct your local Docker daemon to trust that certificate. This is done by copying the `registry_ca.pem` file to `/etc/docker/certs.d/registry.<grid_name>.kontena.local/ca.crt`.


### Authentication

Kontena Image Registry supports basic authentication. Authentication can be enabled by writing `REGISTRY_AUTH_PASSWORD` to Kontena Vault:

```
$ kontena vault write REGISTRY_AUTH_PASSWORD <password>
```

And then updating the service with the auth secret to read it from Vault:

```
$ kontena service update --secret REGISTRY_AUTH_PASSWORD:AUTH_PASSWORD:env registry/api
```

After the password has been set you should redeploy the registry service:

```
$ kontena service deploy --force registry/api
```

Log in to registry using the Docker CLI:

```
$ docker login -u admin -e not@val.id -p <registry_password> registry.<grid_name>.kontena.local
```
