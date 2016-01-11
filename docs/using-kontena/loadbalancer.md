---
title: Load Balancer
toc_order: 6
---

# Kontena Load Balancer

Load balancers are used to distribute traffic between services. Therefore, having a fully featured, high performance and reliable load balancer is one of the most essential component for building applications composed of multiple services.

With Kontena, developers can enjoy the built-in load balancer that is based on [HAproxy](http://www.haproxy.org/). It is fully managed by Kontena orchestration and enable consistent, portable load balancing on any infrastructure where Kontena Nodes are running.

The Kontena Load Balancer key features:

* Zero downtime when load balancer configuration changes
* Fully automated configuration
* Dynamic routing
* Support for TCP and HTTP traffic
* SSL termination on multiple certificates
* Link certificates from Kontena Vault

## Using Kontena Load Balancer

Kontena Load Balancer is a HAproxy / confd service that is configured to watch changes in etcd. Load Balancers may be described in `kontena.yml` and services are connected automatically by linking services to these load balancer services. If load balanced service is scaled/re-deployed then the load balancer will reload it's configuration on the fly without dropping connections.

An example of Internet facing load balancer:

```
internet_lb:
  image: kontena/lb:latest
  ports:
    - 80:80

web:
  image: nginx:latest
  environment:
    - KONTENA_LB_MODE=http
    - KONTENA_LB_BALANCE=roundrobin
    - KONTENA_LB_INTERNAL_PORT=80
    - KONTENA_LB_VIRTUAL_HOSTS=www.kontena.io,kontena.io
  links:
    - internet_lb
api:
  image: registry.kontena.local/restapi:latest
  environment:
    - KONTENA_LB_MODE=http
    - KONTENA_LB_BALANCE=roundrobin
    - KONTENA_LB_INTERNAL_PORT=8080
    - KONTENA_LB_VIRTUAL_PATH=/api
  links:
    - internet_lb
```

An example of internal TCP load balancer:

```
galera_lb:
  image: kontena/lb:latest

galera:
  image: registry.kontena.local/galera:latest
  environment:
    - KONTENA_LB_MODE=tcp
    - KONTENA_LB_BALANCE=leastcon
    - KONTENA_LB_EXTERNAL_PORT=3306
    - KONTENA_LB_INTERNAL_PORT=3306
  links:
    - galera_lb
```

## SSL Termination

Kontena Load Balancer supports ssl termination on multiple certificates. These certificates can be configured to load balancer by setting `SSL_CERTS` environment variable. Recommended way to do this is by using Kontena Vault.

The certificate specified in Kontena Load Balancer is a pem file, containing a public certificate followed by a private key (public certificate must be put before the private key, order matters).

You can run the following script to generate a self-signed certificate:

```
$ openssl req -x509 -newkey rsa:2048 -keyout key.pem -out ca.pem -days 1080 -nodes -subj '/CN=*/O=My Company Name LTD./C=US'
$ cat ca.pem key.pem > cert.pem
```

Once you have the pem file, you can save it to the Kontena Vault:

```
$ kontena vault write my_company_cert "$(cat cert.pem)"
```

And finally you can link the certificate from Vault to your load balancer:

```
loadbalancer:
  image: kontena/lb:latest
  ports:
    - 443:443
  secrets:
    - secret: my_company_cert
      name: SSL_CERTS
      type: env
```


#### An example with 2 certificates (www.domain.com and api.domain.com):

Write certificates to Kontena Vault:

```
$ kontena vault write www_domain_com_cert "$(cat www_domain_com.pem)"
$ kontena vault write api_domain_com_cert "$(cat api_domain_com.pem)"
```
(pem files must contain both public certificate and private key)

Map secrets from Vault to lb service:

```
loadbalancer:
  image: kontena/lb:latest
  ports:
    - 443:443
  secrets:
    - secret: www_domain_com_cert
      name: SSL_CERTS
      type: env
    - secret: api_domain_com_cert
      name: SSL_CERTS
      type: env
```

## Config Env variables for balanced services

* `KONTENA_LB_MODE`: mode of load balancing, possible values: http (default), tcp
* `KONTENA_LB_BALANCE`: load balancing algorithm to use, possible values are: roundrobin (default), source, leastcon
* `KONTENA_LB_INTERNAL_PORT`: service port that is attached to load balancer
* `KONTENA_LB_EXTERNAL_PORT`: service port that load balancer starts to listen (only for tcp mode)
* `KONTENA_LB_VIRTUAL_HOSTS`: comma separated list of virtual hosts (only for http mode)
* `KONTENA_LB_VIRTUAL_PATH`: path that is used to match request, example "/api" (only for http mode)
* `KONTENA_LB_CUSTOM_SETTINGS`: extra settings, each line will be appended to either related backend section or listen session in the HAProxy configuration file
