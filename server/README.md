# Kontena Server
[![Build Status](https://travis-ci.org/kontena/kontena-server.svg?branch=master)](https://travis-ci.org/kontena/kontena-server)

## Features

* Access control
* Orchestrates multiple Docker grids (clusters)
* Container logs
* Container metrics
* Audit log
* Service abstraction
* Scheduler
* Realtime (websocket) channel to Kontena Agents

## Installation

> Prerequisities: [Docker](https://www.docker.com) 1.4 or later

### Ubuntu 14.04

```sh
echo "deb http://dl.bintray.com/kontena/kontena /" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get install kontena-server
```

#### Configure SSL

```sh
$ sudo vim /etc/default/kontena-server-haproxy

# HAProxy SSL certificate
SSL_CERT=/path/to/certificate.pem
```

**Note:** If you want to install Kontena Server to the same host that has Kontena Agent, please install and configure [`kontena-weave`](https://github.com/kontena/kontena-agent#modify-docker-network-config) package first.

#### Start server

```sh
$ sudo start kontena-server-api
```

Server should now listen on port 8443 or 8080 depending on have you configured SSL or not.

## Development

### Get started

Start app
```sh
$ docker-compose up
```

Build:

```sh
$ docker build -t kontena/server .
```


## License

Kontena is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for full license text.
