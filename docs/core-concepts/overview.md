# Kontena Overview

Kontena is an open-source system for deploying, managing, scaling and monitoring containerized applications across multiple hosts on any cloud infrastructure. It is primarily targeted for running applications composed of multiple containers, such as elastic, distributed micro-services.

With Kontena, user is asking system to run a Service that is composed of one or more containers. The system will then automatically choose the host or number of hosts to run those containers. Kontena's scheduler has been influenced by technologies such as [Docker Swarm](https://docs.docker.com/swarm/) and [Kubernetes](http://kubernetes.io/). While having many similarities and concepts, Kontena's scheduler is designed to:

* Work with Services instead of plain containers
* Support both stateless and stateful applications
* Have sane defaults and prefer convention over configuration

Once containers are ready to be started on the hosts, Kontena will apply virtual overlay network for containers to make it possible for containers to find and communicate with each other.

## The Grid

Grid is the top level abstraction in Kontena. It is created by and managed by Master Node.

When Grid is created, Kontena will automatically create an overlay network (powered by [Weave](http://weave.works/)) with VPN access available. All the Nodes of a Grid are automatically connected to this overlay network. With overlay network in place, Services may communicate with each other in multi-host environment just like in a local area network. Kontena's built-in VPN solution allows developers to access the overlay network from local development environments with [OpenVPN](https://openvpn.net/).

## Master Node

Master Node is a machine providing APIs to manage Grids, Nodes and Services. In addition, Master Node is collecting log streams and statistics from the Host Nodes and Services.

Users must login to Master Node in order to access the Master Node APIs. By default, Master Node is enforcing access control to Grids and maintains audit trail log from all user actions.

Each Master Node may be used to manage multiple Grids. Each Grid must be assigned with dedicated set of Host Nodes to provide the computing power. Therefore, unlike Host Nodes, Master Node by itself does not provide any computing power for any of the Services.

Typically, organizations do not require multiple Master Nodes since single Master Node may be used to manage containerized applications running on multiple different cloud platforms and data centers.

## Host Nodes

Host Nodes are responsible for delivering the computing power for the Grid. In essence, Host Nodes are machines (virtual or physical) running Linux operating system and delivers CPU, memory and disk space to be used collectively by Services in a Grid.

Each Host Node is assigned to a Grid. Additional Host Nodes may be added to Grid to increase the capacity available for Services. It is also possible to remove Host Nodes from a Grid to decrease the capacity available if needed.

Host Nodes communicate to Master Node via secure WebSocket channel. It is used for Service orchestration, management, statistics and log streams. The channel is opened from Host Nodes to Master Node in order to enable *Nodes behind the firewall* operations.

## Services

Just like any container orchestration solution, Kontena supports creation of stateless Services like web servers, REST API servers and in-memory object caches. In addition, Kontena has support for stateful Services such as traditional and distributed databases, batch and streaming data processing. The support for stateful Services is is one of the key differentiators to other container orchestration solutions.
