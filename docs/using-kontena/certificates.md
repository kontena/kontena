---
title: Certificate Management
toc_order: 6
---

# Kontena Certificates

Kontena integrates natively with [LetsEncrypt](letsencrypt.org) to bring easy to use certificate management for your services.

Certificate management is integrated with Kontena [vault](vault.md) to handle certificates with proper security constraints.

## Register for LE

To be able to use LetsEncrypt one must first register as user.
```
kontena certificate register <you@example.com>
```

By default this creates a new private key to be used with LE to identify the client.

**Note:** If you have already registered with other means and have existing private key you wish to use you can import it into vault using specific name `LE_PRIVATE_KEY`
```
$ kontena vault write LE_PRIVATE_KEY "$(cat priv_key.pem)"
```

The email is needed for Let's Encrypt to notify when certificates are about to expire. This registration is neede only once per grid.

## Create domain authorization

To be able to request certificates for a domain one must first prove that you are in charge of tht domain. For this Kontena certificate management support DNS based authorization.

```
$ kontena certificate authorize api.example.com
Record name:_acme-challenge
Record type:TXT
Record content:5m1FCaNvneLduTN4AcPqAbyuQhBQA4ESisAQfEYvXIE
```

To verify that you really control the requested domain, create a DNS TXT record for domain `_acme-challenge.api.example.com` with content specified in the response.

## Get actual certificate

Once you have created the necessary DNS proofs of domain control you can request the actual certificate.

```
$ kontena certificate get --secret-name SSL_CERT_LE_TEST api.example.com
Certificate successfully received and stored into vault with key SSL_CERT_LE_TEST
```

Kontena automatically stores the certificate into secure vault in a format where it can be used for SSL termination with our loadbalancer. If you omit the secret-name option Kontena automatically generates the name using the domain name.

LetsEncrypt does NOT support wildcard certificates. In many cases there's a need to server multiple sites behind one certificate and for that LE supports a concept called subject alternative names (SAN). To obtain a certificate for multiple DNS names just specify them in the request:
```
$ kontena certificate get --secret-name SSL_CERT_LE_TEST example.com www.example.com
Certificate successfully received and stored into vault with key SSL_CERT_LE_TEST
```
**Note:** For each of the domains in the certificate request you have to complete the domain authorization first! The first domain in the list becomes the common name and others are used as alternative names:
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

By default Kontena stores the full chain version of the certificate. This is because LE intermediaries are not trusted by all client libraries (some Rubies, Docker, wget, ...). You can control the type of certificate stored by this command line option:
```
--cert-type CERT_TYPE    The type of certificate to get: fullchain, chain or cert (default: "fullchain")
```


## Secrets

Kontena LE integration stores all certificate information securely in [Kontena Vault](vault.md). Upon receiving a certificate from LetsEncrypt Kontena stores three secrets in the vault:
**LE_CERTIFICATE_`<domain_name>`_PRIVATE_KEY** Private key of the certificate
**LE_CERTIFICATE_`<domain_name>`_CERTIFICATE** The actual certificate
**LE_CERTIFICATE_`<domain_name>`_BUNDLE** Bundle of the certificate and private key, suitable to use with [Kontena Loadbalancer](loadbalancer.md).

These can be used with any software that can utilize secrets from environment using normal [secret integration](vault.md#using-secrets-with-applications).
