---
title: Master (production)
toc_order: 2
---

# Installing Kontena Master for Production


### CoreOS

Example cloud-config (replace SSL certificate):

```yaml
#cloud-config
write_files:
  - path: /etc/kontena-server.env
    permissions: 0600
    owner: root
    content: |
      KONTENA_VERSION=latest
      SSL_CERT="/etc/kontena-server.pem"

  - path: /etc/kontena-server.pem
    permissions: 0600
    owner: root
    content: |
      <your ssl_certificate encoded with "awk 1 ORS='\\n' cert.pem">

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
        -p 8080:80 -p 8443:443 kontena/haproxy:latest
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
