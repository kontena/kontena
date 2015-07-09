---
title: Kontena FAQ
toc_order: 2
---

# Kontena FAQ

## What is Kontena?

Kontena is an open source project for orchestrating and running containerized workloads on a cluster. Kontena system is comprised of a number of **Kontena Nodes** (machines or VMs that run containerized workloads) and a **Kontena Master** that controls and monitors the Nodes.

With Kontena, you can describe your application with **Kontena Service** definition. A Service definition describes the container image, networking, scaling and stateful/stateless attributes for your application. Services may be linked together to create desired architecture. Each service is automatically assigned with internal DNS address that can be used inside your application for inter-Service communications.

The summary of Kontena key features:
* Scheduler with affinity filtering
* Built-in private Docker image registry
* Remote VPN access for workload services
* Ready made load-balancing service
* Log and statistics aggregation with streaming
* Access control and roles for Kontena users

Kontena is used with Kontena command line interface **Kontena CLI**. At the moment, there is no graphical (web based) UI for Kontena.

## How do I get started with Kontena?

We recommend you'll start with our [quick start](getting-started/quick-start.md) guide.

## Is Kontena ready for production?

Long answer: We don't claim Kontena is ready for production at the moment. However, it is one of the most complete and stable systems for running containerized workloads you'll find. We are aware of people running Kontena on production and they provide us with valuable feedback.

Short answer: No.
