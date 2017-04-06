---
title: Environment Variables
toc_order: 2
---

# Environment Variables

## Kontena Master

- `MONGODB_URI`: MongoDB connection uri (required)
- `VAULT_KEY`: secret key for the Kontena Vault (required)
- `VAULT_IV`: initialization vector for the Kontena Vault (required)
- `WEB_CONCURRENCY`: number of forked master api worker processes (default: Number of CPU cores available)
- `MAX_THREADS`: number of threads inside single master api worker process (default: 8)
- `LOG_LEVEL`: logging level
- `ACME_ENDPOINT`: acme endpoint for Let's Encrypt
- `AUTH_API_URL`: specifies authentication server url (default: https://auth.kontena.io)

## Kontena Agent

- `KONTENA_URI`: Kontena Master websocket uri (required)
- `KONTENA_TOKEN`: Kontena Grid token (required)
- `KONTENA_PEER_INTERFACE`: network interface for peer/private communication (default: eth1)
- `KONTENA_PUBLIC_IP`: specify node public ip, overrides default resolving
- `KONTENA_PRIVATE_IP`: specify node private ip, overrides default resolving
- `LOG_LEVEL`: logging level
- `ETCD_IMAGE`: etcd image (default: kontena/etcd)
- `ETCD_VERSION`: etcd image version
- `CADVISOR_IMAGE`: cadvisor image (default: kontena/cadvisor)
- `CADVISOR_VERSION`: cadvisor image version
- `CADVISOR_DISABLED`: if set to `true` agent won't start cadvisor at all
- `WEAVE_IMAGE`: weave net image (default: weaveworks/weave)
- `WEAVEEXEC_IMAGE`: weave exec image (default: weaveworks/weaveexec)
- `WEAVE_VERSION`: weave net version

## Kontena CLI

- `KONTENA_URL`: Kontena Master URL
- `KONTENA_GRID`: Kontena Grid name
- `KONTENA_TOKEN`: Kontena Master access token
- `KONTENA_MASTER`: use existing Kontena Master from CLI config file
- `SSL_IGNORE_ERRORS`: set true to bypass certificate errors
- `DEBUG`: set true to get verbose messages
- `EXCON_DEBUG`: set true to get verbose messages from network calls

## Kontena services

Each service container deployed by Kontena gets populated by following environment variables in addition to the ones defined in the service configuration and in the container image:

- `KONTENA_SERVICE_ID`: Internal service id of the service
- `KONTENA_SERVICE_NAME`: Name of the service
- `KONTENA_GRID_NAME`: Name of the grid service is running in
- `KONTENA_STACK_NAME`: Name of the stack service belongs to
- `KONTENA_NODE_NAME`: The name of the node service is deployed into
- `KONTENA_SERVICE_INSTANCE_NUMBER`: Instance number of the service. 1..n
