---
title: What is Kontena?
toc_order: 1
---

# What is Kontena?

[Kontena](http://www.kontena.io) is an open source project for orchestrating and running containerized workloads on a cluster. Kontena system is comprised of a number of **Kontena Nodes** (machines or VMs that run containerized workloads) and a **Kontena Master** that controls and monitors the Nodes.

With Kontena, you can describe your application with **Kontena Service** definition. A Service definition describes the container image, networking, scaling and stateful/stateless attributes for your application. Services may be linked together to create desired architecture. Each service is automatically assigned with internal DNS address that can be used inside your application for inter-Service communications.

The summary of Kontena key features:
* Scheduler with affinity filtering
* Built-in private Docker image registry
* Remote VPN access for workload services
* Ready made load-balancing service
* Log and statistics aggregation with streaming
* Access control and roles for Kontena users

Kontena is used with Kontena command line interface **Kontena CLI**. At the moment, there is no graphical (web based) UI for Kontena.

# Learn More

> If you are new to Kontena, it’s recommended to first go through the [quick start](getting-started/quick-start.md) guide.

This documentation is a work in progress, so any feedback and requests are welcome. If you feel like something is
missing, please [open an issue](https://github.com/kontena/kontena/issues) at GitHub.