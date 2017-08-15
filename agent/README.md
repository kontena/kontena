# Kontena Agent

[![Build Status](https://travis-ci.org/kontena/kontena-agent.svg?branch=master)](https://travis-ci.org/kontena/kontena-agent)

Kontena is a tool for monitoring and managing containerized services and applications. Kontena Agent runs inside a Docker container and communicates to Kontena Server using WebSockets. Agent handles containers inside a single host node and accepts commands from Kontena Server.

## Features

* Realtime control channel to Kontena server
* Reporting to Kontena server
  * Containers
  * Logs
  * Metrics (collected from [cAdvisor](https://github.com/google/cadvisor))
  * Events
* Cross-node networking (powered by [Weave](https://github.com/zettio/weave))

## Development

Set development env variables to .env file:

```
KONTENA_URI=ws://kontena.local:4040
KONTENA_TOKEN=secret_grid_token
```

Start agent using Docker Compose:

```sh
$ docker-compose up
```

Run specs:

```sh
$ rspec spec/
```

Build:

```sh
$ docker build -t kontena/agent .
```

## License

Kontena is licensed under the Apache License, Version 2.0. See [LICENCE](LICENSE) for full license text.
