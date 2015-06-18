# Kontena

> Application Containers for Masses

[![Build Status](https://travis-ci.org/kontena/kontena.svg?branch=master)](https://travis-ci.org/kontena/kontena)
[![Join the chat at https://gitter.im/kontena/kontena](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/kontena/kontena?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Kontena is an open source container orchestration tool that makes it easy to deploy and manage containerized applications on your own servers.

[![Kontena Introduction](https://asciinema.org/a/20584.png)](https://asciinema.org/a/20584)

The design and architecture of Kontena software is built to provide support for various application container technologies. At the moment, only [Docker](https://github.com/docker/docker) is supported but expect to see support for technologies like [CoreOS Rocket](https://github.com/coreos/rocket) and more in the future.

- [Kontena Website](http://www.kontena.io)
- [Kontena Blog](http://blog.kontena.io)
- [Documentation](docs/)

## Concepts

Kontena works with the following concepts:

- **User** is a devops person that interacts with Kontena. User can have access to multiple grids.
- **Grid** is a cluster of host nodes.
- **Node** is a single server that belongs to grid.
- **Service** is a template used to deploy one or more containers.

## Components

Kontena consists of following components:

- [Server](server/)
- [Agent](agent)
- [CLI](cli/)


## License

Kontena software is open source, and you can use it for any purpose, personal or commercial. Kontena is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for full license text.
