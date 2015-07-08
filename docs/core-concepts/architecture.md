---
title: Architecture
toc_order: 1
---

# Architecture

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

One of the challenges with containerized application infrastructure is the fact that you can not rely on Containers. They come and go. This is happening all the time due to network hardware failures and functionality built-in to Container orchestration to support scaling, migrations, load balancing, rolling updates and restarts. While Containers get their own IP addresses, those IP addresses cannot be relied. Therefore, an abstraction which defines a logical set of Containers, configuration and desired state is needed. In Kontena, this is called a Service.

A Service is composed of Containers based on the same image file. In addition to elementary features such as Service create, deploy, start, stop, scale, update and terminate, Kontena's Service will provide aggregated log and statistics features.

Kontena's built-in support for Service level statistics and logging is very useful since often it is difficult to get an overview and understand the complex system by just inspecting individual Containers. Kontena's Service will also persist all statistics and log data. This is essential due to fact that Containers may not be relied and their built-in log and statistics data may vanish at any time making it impossible to understand what is really going on.

Just like with any container orchestration technology, Kontena supports creation of stateless Services: web servers, REST API servers and in-memory object caches. In addition, Kontena has support for stateful Services such as traditional and distributed databases, batch and streaming data processing. The support for stateful Services is is one of the key differentiators to other container orchestration technologies.
