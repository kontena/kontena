---
title: Kontena FAQ
toc_order: 2
---

# Frequently Asked Questions

## How do I get started with Kontena?

We recommend you'll start with our [quick start](getting-started/quick-start.md) guide.

## What makes Kontena special?

Kontena is built to maximize developer happiness. Due to its simplicity, it does not require dedicated ops teams to administer, operate or maintain the platform. It is a container orchestration platform that just works. Since developers don't need to worry about the platform, they can focus on creating the stuff that matters.

## Who is the ideal user of Kontena?

While Kontena works great for all types of businesses and may be used to run containerized workloads at any scale, it's best suited for start-ups and small to medium sized business who require worry-free and simple to use platform to run containerized workloads.

## How does Kontena compare to Docker Machine/Compose/Swarm, Kubernetes, OpenShift Origin v3, Apache Mesos, Rancher and others?

* **Docker Machine/Compose/Swarm**: Tools from Docker are simple but powerful. Therefore, most people start their container journey using those tools. While these tools work as promised, you'll end up wanting more. With these tools, you are missing integrated overlay networking, DNS, load balancing, aggregated logging, VPN access and private image repository which are crucial for most container workloads. Naturally, you can start adding those technologies yourself but then you'll end up something similar Kontena is already doing as tested, integrated package with great CLI tool.

* **Kubernetes**: Kubernetes by Google is used as a foundation by many container orchestration solutions. It features robust container scheduler and has many great ideas and concepts overlapping with Kontena. However, it does not include overlay networking, DNS, load balancing, aggregated logging, VPN access or private image repository which are crucial for most container workloads. Additionally, the usage of Kubernetes requires awareness of concepts like replication controllers which are quite complex to understand and master. It does not fit the simple user experience we want to achieve with Kontena. We feel it's a great foundation (in fact we planned to use Kubernetes for scheduling in Kontena as well), suitable to build upon, but by itself it's not enough. Kubernetes 1.0 was released in June 2015 which claims to be production ready.

* **OpenShift Origin v3**: OpenShift Origin v3 by Redhat is the latest and greatest OpenShift version yet. It's relying on Kubernetes for container scheduling and adds some of the missing key features. At the moment, OpenShift Origin v3 is one of the most complete solution (on paper) for orchestrating containerized workloads. If you are able to install, operate and maintain the OpenShift Origin v3, you'll get something similar as Kontena. Redhat jumped in the 1.0 bandwagon around the same time with Kubernetes (June 2015).

* **Apache Mesos**: Mesos is a great Apache project for distributed scheduling. It abstracts CPU, memory, storage, and other low level compute resources away from machines, enabling building of elastic and distributed systems. It requires applications be written for Mesos. Frameworks like Marathon provide higher level abstractions suitable to run containers. We feel Apache Mesos with framework like Marathon might be usable by some mega corporations running millions of containers but the overall complexity and required knowledge about machine level primitives makes it unusable to normal human beings.

* **Rancher**: Rancher by Rancher Labs is one of the cool solutions for container orchestration. It has tons of features, nice web based UI and a neat way to authenticate developers with Github user accounts. However, some of the important features like private image registry and VPN access to cluster are missing. Naturally, we expect Rancher to fill-in the gaps at some point. At the moment, it's difficult to say what kind of people Rancher is targeting.

* **Others**: Most of the container orchestration solutions out there are lacking on the features we feel important. Naturally, there are also many projects with similar features and we are all learning from each other. Kontena is trying to deliver best possible solution for container orchestration with a set of features in line with our goal of making something that just works, simple.

## Is Kontena ready for production?

Long answer: We don't claim Kontena is ready for production at the moment. However, it is one of the most complete and stable systems for running containerized workloads you'll find. We are aware of people running Kontena on production and they provide us with valuable feedback.

Short answer: No.
