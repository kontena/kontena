---
title: Load Balancer
---

# Kontena Load Balancer

Load balancers are used to distribute traffic between services. Therefore, having a full-featured, high-performance and reliable load balancer is one of the most essential components for building applications composed of multiple services.

With Kontena, developers can enjoy Kontena's built-in load balancer, which is based on [HAproxy](http://www.haproxy.org/). It is fully managed by Kontena orchestration and enables consistent, portable load balancing on any infrastructure where Kontena Nodes are running.

The Kontena Load Balancer's key features include:

* Zero downtime when load balancer configuration changes
* Fully automated configuration
* Dynamic routing
* Support for TCP and HTTP traffic
* SSL termination on multiple certificates
* Link certificates from Kontena Vault

## Using Kontena Load Balancer

Kontena Load Balancer is a HAproxy / confd service that is configured to watch changes in etcd. Load Balancers may be described in `kontena.yml` and services are connected automatically by linking services to these load balancer services. If a load-balanced service is scaled or redeployed, then the load balancer will reload its configuration on the fly without dropping connections.

Here is an example of an Internet-facing load balancer:

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

Always remember to link your service to Kontena Load Balancer, since the linking activates the load balancing functionality.

Here is an example of an internal TCP load balancer:

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

## Config Env Variables for Kontena Load Balancer

These environment variables configure the load balancer itself.

* `KONTENA_LB_HEALTH_URI` - URI at which to enable Kontena Load Balancer level health check endpoint. Returns `200 OK` when Kontena Load Balancer is functional.
* `STATS_PASSWORD` - The password for accessing Kontena Load Balancer statistics.
* `SSL_CERTS` - SSL certificates to be used. See more at [SSL Termination](loadbalancer#ssl-termination).
* `KONTENA_LB_SSL_CIPHERS` - SSL Cipher suite used by the loadbalancer when operating in SSL mode. See more at [SSL Ciphers](loadbalancer#configuringcustomsslciphers)

## Stats

Kontena Load Balancer exposes a statistics web UI only on the private overlay network. To access the statistics you must use the [VPN](vpn-access) to access the overlay network. The statistics are exposed on port 1000 of the Kontena Load Balancer instances.

## Basic authentication for services

Kontena Load Balancer supports automatic [basic authentication](https://en.wikipedia.org/wiki/Basic_access_authentication) for balanced services. To enable basic authentication on a given service, use the following configuration:
```
version: 2
services:
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
    secrets:
      - secret: BASIC_AUTH_FOR_XYZ
        name: KONTENA_LB_BASIC_AUTH_SECRETS
        type: env

```

To write the configuration to the Vault, use the following:
```
$ kontena vault write BASIC_AUTH_FOR_XYZ << EOF
→ user user1 password <bcrypt_password>
→ user user2 insecure-password pass1234
→ EOF
```

If you want to use encrypted passwords, note that encrypted passwords are evaluated using the crypt(3) function in order to support different algorithms. For example, MD5, SHA-256 and SHA-512 are supported. To generate an encrypted password you can use the following examples:
```
mkpasswd -m sha-512 passwd
```
Or, if your system does not have `mkpasswd` available but you have Docker available, use the following:
```
docker run -ti --rm alpine mkpasswd -m sha-512 passwd
```

## SSL Termination

Kontena Load Balancer supports ssl termination on multiple certificates. These certificates can be configured for the load balancer by setting the `SSL_CERTS` environment variable. The recommended way to do this is by using Kontena Vault.

The certificate specified in Kontena Load Balancer is a pem file, which contains a public certificate followed by a private key. (The public certificate must be placed before the private key; order matters.)

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
(Pem files must contain both a public certificate and a private key.)

Map secrets from Vault to the Kontena Load Balancer:

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

### Configuring custom SSL Ciphers

By default Kontena Loadbalancer uses strong SSL cipher suite, see:
https://github.com/kontena/kontena-loadbalancer/blob/master/confd/templates/haproxy.tmpl#L9

In some cases it is required to have somewhat customized cipher suite to cater specific security requirements or other such needs.

 This can be achieved by using specific environment variable for the loadbalancer service:
 ```
 KONTENA_LB_SSL_CIPHERS=ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384
 ```



## Config Env Variables for Load Balanced Services

These options are defined on the services that are balanced through Kontena Load Balancer.

* `KONTENA_LB_MODE`: mode of load balancing; possible values: http (default), tcp
* `KONTENA_LB_BALANCE`: load-balancing algorithm to use; possible values: roundrobin (default), source, leastcon
* `KONTENA_LB_INTERNAL_PORT`: service port that is attached to load balancer
* `KONTENA_LB_EXTERNAL_PORT`: service port that load balancer starts to listen (only for tcp mode)
* `KONTENA_LB_VIRTUAL_HOSTS`: comma-separated list of virtual hosts (only for http mode)
* `KONTENA_LB_VIRTUAL_PATH`: path that is used to match request; example: "/api" (only for http mode)
* `KONTENA_LB_KEEP_VIRTUAL_PATH`: if set to true, virtual path will be kept in request path (only for http mode)
* `KONTENA_LB_CUSTOM_SETTINGS`: extra settings; each line will be appended to either the related backend section or the listen session in the HAProxy configuration file
* `KONTENA_LB_COOKIE`: Enables cookie-based session stickiness. With empty value, it defaults to the load balancer-set cookie. Can be customized to use application cookies. See details at [HAProxy docs](https://cbonte.github.io/haproxy-dconv/configuration-1.5.html#4.2-cookie)
