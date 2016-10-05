---
title: VPN Access
toc_order: 4
---

# VPN Access

All Kontena [Services](services.md) run inside a virtual private network by default. Therefore, none of the Services are
exposed to the Internet unless explicitly defined. The benefits are obvious; most of the modern micro-service architectures
expose only the frontend of the application to the Internet while keeping internal services such as databases sealed off
from any unauthorized access. The frontend application may access the database since they belong to the same virtual
private network. This is great architecture, but has some challenges when the entire platform is based on containers.

Developers and DevOps teams will require access to any internal services. For example, it is often required to make
some database backups. It is also desired that they can use the existing standard tools for these maintenance operations.
With Kontena, this is possible due to built-in VPN access to the virtual private network where all services are running.

You should use the Kontena's built-in VPN access if you want to:

* Create your application with micro-service architecture; expose only the front-end part of your application.
* Use Kontena's built-in [Image Registry](image-registry.md) for storing your own application container images.
* Focus on developing your application instead of tooling around it.


## Using VPN

#### Create VPN Service:

```
$ kontena vpn create
Usage:
    kontena vpn create [OPTIONS]

Options:
    --node NODE                   Node name where VPN is deployed
    --ip IP                       Node ip-address to use in VPN service configuration
```

Use the `--node` and/or `--ip` option to override automatic node selection and IP detection in private network setups.

> VPN service uses port 1194 (udp), remember to open it to nodes if you are using a firewall!


#### Export VPN Configuration:

```
$ kontena vpn config > /path/to/kontena.ovpn
```

`kontena.ovpn` configuration file can be then imported to your favorite OpenVPN client.

#### Delete VPN Service:

```
$ kontena vpn remove
```
