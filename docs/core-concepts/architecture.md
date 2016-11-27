---
title: Architecture
toc_order: 1
---

# Architecture

Kontena is an open-source system for deploying, managing, scaling and monitoring containerized applications across multiple hosts on any cloud infrastructure. It is primarily designed for running applications composed of multiple containers, such as elastic, distributed micro-services.

With Kontena, the user starts by telling the Kontena system to run a Service that is composed of one or more containers. The Kontena system will then automatically choose the host or hosts to run those containers. Kontena's scheduler has been influenced by technologies such as [Docker Swarm](https://docs.docker.com/swarm/) and [Kubernetes](http://kubernetes.io/). While the Kontena scheduler shares many similarities and concepts with these container orchestrators, Kontena's scheduler is designed to:

* Work with Services instead of plain containers
* Support both stateless and stateful applications
* Have sane defaults and prefer convention over configuration

Once the containers are ready to be started on the hosts, Kontena will apply a virtual overlay network for the containers to make it possible for them to find and communicate with each other.

## The Grid

a Grid provides the top-level abstraction in Kontena. It is created and managed by Master Node.

When a Grid is created, Kontena will automatically create an overlay network (powered by [Weave](http://weave.works/)) with VPN access available. All of a Grid's Nodes are automatically connected to this overlay network. With the overlay network in place, Services may communicate with each other in multi-host environments just like in a local area network. Kontena's built-in VPN solution allows developers to access the overlay network from local development environments with [OpenVPN](https://openvpn.net/).

## Master Node

The Master Node is a machine providing APIs to manage Grids, Nodes and Services. In addition, the Master Node collects log streams and statistics from the Host Nodes and Services.

Users must log in to the Master Node in order to access the Master Node APIs. By default, the Master Node enforces access control to Grids and maintains an audit trail log of all user actions.

Each Master Node may be used to manage multiple Grids. Each Grid must be assigned a dedicated set of Host Nodes to provide the computing power. Therefore, unlike Host Nodes, the Master Node by itself does not provide any computing power for any of the Services.

Typically, organizations do not require multiple Master Nodes, since a single Master Node may be used to manage containerized applications running on multiple different cloud platforms and data centers.

## Host Nodes

Host Nodes are responsible for delivering the computing power for the Grid. In essence, Host Nodes are machines (virtual or physical) that run the Linux operating system and deliver CPU, memory and disk space, which can be used collectively by Services in a Grid.

Each Host Node is assigned to a Grid. Additional Host Nodes may be added to a Grid to increase the capacity available for Services. It is also possible to remove Host Nodes from a Grid to decrease the available capacity if desired.

Host Nodes communicate with the Master Node via a secure WebSocket channel. The WebSocket channel is used for Service orchestration, management, statistics and log streams. The channel is opened from Host Nodes to the Master Node in order to enable *Nodes behind the firewall* operations.

## Services

One of the challenges with containerized application infrastructure is the fact that you cannot rely on individual containers, because containers are ephemeral environments that come and go. They spin up and down in response to both network hardware failures and functionality built into the container orchestrator in order to support scaling, migrations, load balancing, rolling updates and restarts. While containers get their own IP addresses, those IP addresses cannot be predicted in advance. Therefore, an abstraction that defines a logical set of containers, their configuration and their desired state is needed. In Kontena, this is called a Service.

A Service is composed of containers based on the same image file. In addition to elementary features such as Service create, deploy, start, stop, scale, update and terminate, Kontena's Services provide aggregated log and statistics features.

Kontena's built-in support for Service-level statistics and logging is very useful since it is often difficult to get an overview and understand a complex system by just inspecting individual containers. In addition, Kontena's Services make all statistics and log data persistent. This is essential due to the fact that individual containers do not store this information persistently.

As with any container orchestration technology, Kontena supports the creation of stateless Services: web servers, REST API servers and in-memory object caches. In addition, Kontena has support for stateful Services such as traditional and distributed databases and batch and streaming data processing. The support for stateful Services is one of the key differentiators between Kontena and other container orchestration technologies.

## Stacks

An individual service is rarely useful on its own.
Modern microservice architectures will decompose applications into many smaller services, and even monolithic web applications will typically require some external services such as a database.
Deploying these applications requires careful management of the different combinations of services, and the ability for those services to communicate amongst themselves.
Deploying a re-usable application into different environments may require the use of configuration variables to customize the application.
Kontena Stacks are used to distribute, deploy and run pre-packaged and reusable collections of multiple services with any associated configuration.

Each Kontena Stack can be distributed as a YAML file via the ***Stack Registry***, deployed as a Stack via the ***Kontena Master***, and run as ***Service Containers*** in a per-stack namespace within the ***Grid***.
The use of a per-stack namespace allows simple communication between the services within a stack, while also allowing multiple instances of the same stack to be run within the same ***Grid***.
Stacks can also use services exposed by other stacks deployed to the same grid.
