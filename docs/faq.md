---
title: Kontena FAQ
toc_order: 2
---

# Frequently Asked Questions

## How do I get started with Kontena?

We recommend that you start with our [quick start](getting-started/quick-start.md) guide.

## What makes Kontena special?

Kontena is built to maximize developer happiness. Due to its simplicity, it does not require dedicated ops teams to administer, operate or maintain the platform. It is a container orchestration platform that just works. Since developers don't need to worry about the platform, they can focus on creating the stuff that matters.

## Who is the ideal user of Kontena?

While Kontena works great for all types of businesses and may be used to run containerized workloads at any scale, it's best suited for start-ups and small to medium sized businesses that require a worry-free, simple-to-use platform for running containerized workloads.

## How does Kontena compare to Docker Machine/Compose/Swarm, Kubernetes, OpenShift Origin v3, Apache Mesos, Rancher and others?

* **Docker Machine/Compose/Swarm**: Tools from Docker are simple but powerful. Therefore, most people start their container journey using those tools. However, while these tools work as promised, you'll end up wanting more. With these tools, you are missing integrated overlay networking, DNS, load balancing, aggregated logging, VPN access and private image repositories, all of which are crucial for most container workloads. Naturally, you can start adding those technologies yourself, but then you'll end up building something similar to what Kontena is already doing -- a tested, integrated package with great CLI tools. So instead of building it all yourself, why not just adopt Kontena's ready-made solution?

* **Kubernetes**: Kubernetes by Google is used as a foundation by many container orchestration solutions. It features a robust container scheduler and offers many great ideas and concepts that overlap with Kontena. However, it does not include overlay networking, DNS, load balancing, aggregated logging, VPN access or private image repositories, all of which are crucial for most container workloads. Additionally, using Kubernetes requires expertise in concepts like replication controllers, which are quite complex to understand and master. Kuberentes therefore does not deliver the simple user experience we want to achieve with Kontena. We feel that Kubernetes is a great foundation (in fact, we planned to use Kubernetes for scheduling in Kontena as well), but by itself it's not enough.

* **OpenShift Origin v3**: OpenShift Origin v3 by Redhat is the latest and greatest OpenShift version yet. It leverages on Kubernetes for container scheduling and adds some of the key features missing from Kubernetes. At the moment, OpenShift Origin v3 is one of the most complete solutions (on paper) for orchestrating containerized workloads. If you are able to install, operate and maintain the OpenShift Origin v3, you'll get something similar to Kontena -- but we think OpenShift Origin is much more difficult to set up and administer than Kontena.

* **Apache Mesos**: Mesos is a great Apache project for distributed scheduling. It abstracts CPU, memory, storage, and other low level compute resources away from machines, enabling users to build elastic, distributed systems. However, it requires applications to be written specifically for Mesos. Frameworks like Marathon provide higher-level abstractions suitable for running containers. We feel that using Apache Mesos in conjunction with a framework like Marathon might be usable by some large corporations running millions of containers. However, the overall complexity required by this setup, and the expertise with machine level primitives that it demands, makes it an unrealistic solution for most admins, especially at small and medium-sized businesses.

* **Rancher**: Rancher, developed by Rancher Labs, is a cool solution for container orchestration. It offers tons of features, a nice web-based UI and a neat way to authenticate developers with Github user accounts. However, some important features, such as a private image registry and VPN access to clusters, are missing. Naturally, we expect Rancher to fill in the gaps at some point. At the moment, however, it's difficult to say what kind of people Rancher is targeting given the current pieces of missing functionality.

* **Others**: Most of the other container orchestration solutions out there are lacking the features we feel are important. Naturally, there are also many projects with features similar to Kontena, and we are all learning from each other. Kontena aims to deliver the best possible solution for container orchestration with a set of features that are in line with our goal of making something that just works, plain and simple.

## Is Kontena ready for production?

Long answer: We don't claim Kontena is ready for production at the moment in most situations. However, it is one of the most complete and stable systems for running containerized workloads that you'll find. In addition, we are aware of some users who are currently running Kontena for production workloads.

Short answer: No.
