---
title: Certificate Management
---

# Kontena Certificates

Kontena integrates natively with [LetsEncrypt](letsencrypt.org) to provide easy-to-use certificate management for your services.

Certificate management is integrated with Kontena [vault](vault.md) to handle certificates with the proper security constraints.

## Register for LE

To use LetsEncrypt, you must first register as a user.

```
kontena certificate register <you@example.com>
```

By default this creates a new private key to be used with LE to identify the client.

**Note:** If you have already registered with other means and have an existing private key you wish to use you can import it into vault using the specific name `LE_PRIVATE_KEY`
```
$ kontena vault write LE_PRIVATE_KEY "$(cat priv_key.pem)"
```

The email is needed for Let's Encrypt to notify when certificates are about to expire. This registration is needed only once per grid.

## Create domain authorization

To be able to request certificates for a domain you must first prove that you are in charge of that domain. For this, Kontena certificate management supports DNS-based and TLS-SNI based authorizations.

### TLS-SNI based authorization

When using `tls-sni-0` verification method, Kontena will interact with Let's Encrypt and creates a specially crafted self-signed certificate. Once that certificate is bundled to a loadbalancer, Let's Encrypt can verify the DNS control for the domain. So remember to point the DNS records of the domain, for which the certificate is being created on, to the loadbalancer public IP addresses. When creating the auhtorization Kontena will automatically attach the special self-signed certificate to the given loadbalancer service through using a secret.

```bash
$ kontena certificate authorize --auth-type tls-sni-01 --lb-link infra/lb  api.example.com
Authorization successfully created. Use the following details to create necessary validations:
Point the public DNS A record of api.example.com to the public IP address(es) of the infra/lb
```

### DNS based authorization

To create a challenge for DNS based authorization use:

```bash
$ kontena certificate authorize --auth-type dns-01 api.example.com
Authorization successfully created. Use the following details to create necessary validations:
Record name: _acme-challenge.api.example.com
Record type: TXT
Record content: jEeBHU0WtHhnf0ZRXBbN0nYnjcBWlSS7TFiXvjFs62k
```

To verify that you really control the requested domain, create a DNS TXT record for the domain `_acme-challenge.api.example.com` with content specified in the response.

## Get actual certificate

Once you have created the necessary proof of domain control you can request the actual certificate.

```
$ kontena certificate get --secret-name SSL_CERT_LE_TEST api.example.com
Certificate successfully received and stored into vault with key SSL_CERT_LE_TEST
```

Kontena automatically stores the certificate in a secure vault in a format where it can be used for SSL termination with Kontena Load Balancer. If you omit the secret-name option, Kontena automatically generates the name using the domain name.

LetsEncrypt does NOT support wildcard certificates. In many cases it is necessary to serve multiple sites behind one certificate. For this, LetsEncrypt supports a concept called subject alternative names (SAN). To obtain a certificate for multiple DNS names, simply specify them in the request:
```
$ kontena certificate get --secret-name SSL_CERT_LE_TEST example.com www.example.com
Certificate successfully received and stored into vault with key SSL_CERT_LE_TEST
```
**Note:** For each of the domains in the certificate request, it is necessary to complete the domain authorization first! The first domain in the list becomes the common name and others are used as alternative names:
```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            fa:2c:99:7a:4e:76:10:97:fe:b9:7b:28:4a:c3:44:7a:fe:b1
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=Fake LE Intermediate X1
        Validity
            Not Before: Jul  1 06:31:00 2016 GMT
            Not After : Sep 29 06:31:00 2016 GMT
        Subject: CN=example.com
        Subject Public Key Info:
        ...
        X509v3 extensions:
            X509v3 Subject Alternative Name:
                DNS:www.example.com, DNS:example.com
```

By default Kontena stores the full chain version of the certificate. This is because LetsEncrypt intermediaries are not trusted by all client libraries (such as some libraries associated with Ruby, Docker, and wget, for example). You can control the type of certificate stored with this command line option:
```
--cert-type CERT_TYPE    The type of certificate to get: fullchain, chain or cert (default: "fullchain")
```


## Secrets

Kontena LetsEncrypt integration stores all certificate information securely in [Kontena Vault](vault.md). Upon receiving a certificate from LetsEncrypt Kontena stores three secrets in the vault:
**LE_CERTIFICATE_`<domain_name>`_PRIVATE_KEY** Private key of the certificate
**LE_CERTIFICATE_`<domain_name>`_CERTIFICATE** The actual certificate
**LE_CERTIFICATE_`<domain_name>`_BUNDLE** Bundle of the certificate and private key, suitable to use with [Kontena Loadbalancer](loadbalancer.md).

These can be used with any software that can utilize secrets from environment using normal [secret integration](vault.md#using-secrets-with-applications).
