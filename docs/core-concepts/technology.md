---
title: Technology
toc_order: 2
---

# Technology

## Docker

> The Linux container engine

## Weave

> Overlay network for Docker

Weave is used as a default overlay network for nodes. Weave provides common network fabric that works everywhere in the same way. Weave has some really nice features that are hard to implement, for example transparent network encryption.

## Etcd

> A highly-available key-value store for shared configuration and service discovery.

Etcd is used as a distributed key-value storage in nodes. Each Kontena grid has one internal etcd cluster that node agents can use.

## Ruby

> Ruby is a dynamic, open source programming language with a focus on simplicity and productivity.

Ruby is our weapon of choice when it comes to server-side coding. Both master and agent daemons are written using ruby. Ruby is really flexible and has lot's of libraries that helps building this kind of stuff.

Some of the rubygems that we rely on:

* roda
* puma
* mongoid
* mutations
* docker-api
* rubydns
* etcd
* celluloid
* rspec

## MongoDB

> MongoDB is an open-source, document database designed for ease of development and scaling.

MongoDB is used as a persistent storage in the master daemon. We did choose MongoDB because of flexibility, tooling and relatively simple scaling.

## cAdvisor

> cAdvisor (Container Advisor) provides container users an understanding of the resource usage and performance characteristics of their running containers.
