---
title: Network Model
toc_order: 2
---

# Network Model

Kontena's network model is based on the [Kontena Grid](#grid), which spans a set of [Host Nodes](#host-node).
The Grid uses an [Overlay Network](#overlay-network) to provide connectivity between [Service Containers](#service-containers) running on different Nodes.

Each host Node is a separate virtual machine, which can have some combination of [Public](#public-network-address) and [Private](#private-network-address) network addresses.
Nodes within the same region can communicate using their Private network address.
The Public network address can be used to access network services exposed by the Node.

Each Grid has a single [Overlay Network](#overlay-network) using a private RFC1918 address space.
The Kontena Agent establishes the Overlay Network mesh between the Nodes.
Nodes and Containers are connected to the overlay network.
Each [Node](#overlay-network-address) and [Service Container](#weave-overlay-network) can use their respective overlay network addresess to communicate within the Grid.
The Grid network also provides [DNS Service Discovery](#dns-service-discovery) for all Services and Service Containers overlay network addresses using the `kontena.local` domain.

Each host Node runs the **Kontena Agent**, which establishes a WebSocket connection to a **Kontena Master**.
The host Node's Kontena Agent and the Master node are only used for cluster management. The Master node is not connected to the Grid, and Containers attached to the Grid cannot communicate with the Kontena Master.
The Master Node does not expose any network services other than the HTTP API used by the CLI and Kontena Agent.

While a Kontena Master can manage multiple Grids, each Grid is an isolated overlay network with its own address space. Nodes and Containers attached to different Grids cannot communicate with each other.

## Grid

Each grid has a single overlay network used for both host nodes and service containers.
The default overlay network for a Kontena grid is `10.81.0.0/16`, but this can be customized using `kontena grid create --subnet=`.
The grid subnet cannot be changed afterwards.
The grid host nodes must not have any local routes that overlap with the grid subnet, or the Kontena grid infrastructure services on the host nodes may not work.

Each Grid may also include a set of Trusted Subnets, which are used for the Overlay Networking between Host Node public and private IP addresses as described further below.

### Subnet and Supernet

Each grid is configured with a single subnet (default `10.81.0.0/16`) and supernet (default `10.80.0.0/12`).
Both of these private RFC1918 IP address spaces are used for internal overlay networking within each grid.
These overlay network addresses are only unique within a grid; different grids can (and will) use the same overlay network IP addresses.

The grid subnet (`10.81.0.0/16`) is used to provide overlay networking addresses for both host nodes and service containers.
The grid subnet is split into two parts: `10.81.0.0/17` and `10.81.128.0/17`.
The lower half is used for the `10.81.0.X` host node overlay network addresses allocated by the Kontena server, and used to bootstrap the grid infrastructure services such as etcd.

The upper half of the grid subnet (`10.81.128.0 - 10.81.255.255`) is used for dynamically allocated service containers, managed by the [Kontena IPAM](https://github.com/kontena/kontena-ipam) using etcd.
Using the default address allocation scheme, each Grid can contain up to 254 Host Nodes, and 32k Service Containers.

The grid supernet (`10.80.0.0/12`) is reserved for future multi-network support, and will be used to dynamically allocate isolated subnets to provide network separation between grid services.

### IP Address Management

The dynamic overlay network addresses used by service containers are allocated by the [Kontena IPAM](https://github.com/kontena/kontena-ipam) service running on each host Node.
The [Kontena IPAM](https://github.com/kontena/kontena-ipam) service uses the Grid's etcd infrstructure service, and will stop working if the Grid loses its etcd majority.

The overlay network address of a Service Container is reserved by the Kontena Agent when it is created, and released by the Kontena Agent when the Service Container is removed.
The Kontena Agent will also periodically cleanup any unused IPAM addresses that the agent was unable to release, which may happen when host nodes shut down.

The service container's overlay network address will remain the same if the service container is restarted, such as when the service crashes.
The service container's overlay network address will change when the service is re-deployed, either to the same or a different host node.

## Host Node

A host Node is a physical or virtual machine running the Docker Engine and Kontena Agent.
The Kontena Agent runs as a Docker container and controls the Docker Engine to manage infrastructure Containers and Service Containers.

### Node Network Addresses
Each host Node has a total of four different network addresses:

#### Public Network Address

  The external Internet address of the machine (`public_ip`)

  The public network address is resolved at startup using the `http://whatismyip.akamai.com` service, or it can be configured using `KONTENA_PUBLIC_IP`.

  The Node's public addess can be used to connect to network services exposed on that host Node. These include ports published by any Kontena Service Container that has been scheduled to run on that Node, including any instance of the Kontena Load Balancer.
  The Node's public address is also used for the Weave control and data plane connections between Nodes.
  The Weave control and data plane ports are the only publically exposed services on a host Node under the default Kontena configuration.

  For a node behind NAT, such as a Vagrant node, the public address may not necessarily work for incoming connections.

#### Private Network Address

  The internal network address of the machine (`private_ip`)

  The private network address is resolved using the interface address configured on the internal interface. Alternatively, it can be configured using `KONTENA_PRIVATE_IP`.
  The internal interface is `eth1`, or the interface given by `KONTENA_PEER_INTERFACE`.
  If the internal interface does not exist, the address on the `eth0` interface is used.

  The private network address is used for the Weave control and data plane communication between nodes within the same region.
  Nodes exist within the same region if they have been configured with the same Docker Engine `region=` label.
  The `region=` label is a string value provided by the provisioning plugin.

  The private network address can also be used for connections to published services on internal nodes within a local network.
  Using the private network address is required for local Vagrant nodes, since the public network address provided by VirtualBox does not allow any incoming connections.

#### Overlay Network Address
  The overlay network address (`10.81.0.x/16`)

  Each Host Node within a Grid is assigned a sequential Node Number, in the range of `1..254`.

  Once the overlay network has been established, the host machine is also configured with a statically allocated overlay network address based on the sequentially assigned Node number.
  The first `/24` of addresses within the overlay network subnet (`10.81.0.X/16`) is reserved for these statically allocated Node overlay network addresses.

  These Node overlay network addresses can be used by both other Nodes and any Service Containers within the same Grid.
  The Node's overlay network address is used for the Grid's infrastructure services, including Kontena's etcd cluster.
  Any Kontena Service container can connect to each host Node's overlay network address.

#### Docker Gateway Address

  The Docker gateway address is (`172.17.0.1` on `docker0`)

  Each Host Node uses the Docker default bridge network to provide Containers with access to the internal network.

  The Docker gateway address also serves as the DNS resolver for the Containers, powered by Weave DNS.

### Node Infrastructure Services
Each host Node runs a number of infrastructure services as Docker containers, using the host network namespace. Networking details are as follows:

| Service   | Protocol | Port | Addresses                 | Description
|-----------|----------|------|---------------------------|-----------------------
| Weave DNS | TCP+UDP  | 53   | `172.17.0.1` (`docker0`)  | Weave DNS
| etcd      | TCP      | 2379 | <ul><li>`127.0.0.1` (`lo`)</li><li>`172.17.0.1` (`docker0`)</li><li>`10.81.0.X` (weave)</li></ul> | etcd Clients
| etcd      | TCP      | 2380 | `10.81.10.X` (weave)       | etcd Peers
| Weave Net | TCP      | 6783 | `*`                       | Weave Net Control
| Weave Net | UDP      | 6783 | `*`                       | Weave Net Data (`sleeve`)
| Weave Net | UDP      | 6784 | `*`                       | Weave Net Data (`fastdp`)

Only the Weave Net service is externally accessible by default. This is required for forming the encrypted Overlay Network mesh between host Nodes.

## Overlay Network

At startup, the Kontena Agent establishes the overlay network mesh between the Grid's Nodes.
The overlay network mesh is used to bootstrap the Grid infrastructure. The host Node's overlay network address is used for infrastructure services such as etcd.

The overlay network is established using the network addresses of the peer Nodes within the Kontena Grid, which the Kontena Agent receives from the Master at startup.
The overlay network mesh uses the Private network address of a peer node within the same Region; otherwise, the Public network address is used.
Once the overlay network is started, the host Node's overlay network address is configured using [`weave expose`](https://www.weave.works/docs/net/latest/using-weave/host-network-integration/).

The overlay network is powered by Weave Net, using [Weave's encrypted `sleeve` tunnels](https://www.weave.works/docs/net/latest/using-weave/security-untrusted-networks/) to form a flat Layer 2 network spanning all Grid Nodes and connected Containers.

Alternatively, [Weave's Fast Datapath](https://www.weave.works/docs/net/latest/using-weave/fastdp/) can be used for traffic between Nodes within the Kontena Grid's [Trusted Subnets](https://kontena.io/docs/using-kontena/grids#grid-trusted-subnets).
Using Trusted Subnets and Weave's Fast Datapath provides [improved performance](https://www.weave.works/weave-docker-networking-performance-fast-data-path/). The cost of this method is a lack of data plane encryption between Nodes.

## Service Containers

Any exposed ports on any Service Container will automatically be internally accessible from other host Nodes and Service Containers within the Grid overlay network.

#### Default Docker Network

The Service Containers are created using the default Docker bridge network, which provides each Container with an isolated network namespace.
The default Docker bridge network is used to provide the Container with a default route for connecting to external services, using SNAT on the host machine.
The default Docker bridge network is local to each Node, and Containers on different nodes will use the same default Docker bridge network subnet of `172.42.17.X/24` on each Container's default `eth0` interface.

The default Docker network provides connectivity to the [Gateway](#docker-gateway-address) address of each host Node, which is used as the [DNS](#dns-service-discovery) resolver.

#### Weave Overlay Network

Each Service Container, once started, is also attached to the Weave network.
The Container's `ethwe` network interface is used for the internal communication between Grid Services, using the Overlay Network's `10.81.0.0/16` subnet.
In order to avoid any issues with Container services attempting to resolve or connect to other services on the overlay network, the `weavewait` utility is used to delay the Container service execution until the Container's Weave network is ready. This procedure uses a modified Docker entrypoint for the Container.


## Publishing Services

Accessing any Service externally requires the Service's ports to be explicitly published, using a list of published TCP and UDP ports, configured in the `kontena.yml`.
These are deployed as published container ports on the Docker default bridge network, using DNAT on the host machine to provide external access to the published services.

The host Node's public (and private) addresses can be used to access those services published by Service Containers running on that Node.
Only one Service can publish any given port on a given Node.
The ports used for infrastructure services on the host Nodes cannot be used to publish other services.

### Kontena Load Balancer

The [Kontena Load Balancer](https://kontena.io/docs/using-kontena/loadbalancer) can also be used to publish services, providing TCP and HTTP load-balancing of multiple Service Container backends with dynamic configuration as services are started, scaled and stopped.
The public network address of any Host Node running the load balancer service can be used by external clients to connect to the load-balanced service containers.
The Kontena Load Balancer should be deployed to nodes having known public network addresses, using either `kontena.yml` `affinity` conditions, or using `deploy: strategy: daemon` to deploy the LB on all nodes.
The public network address of the nodes running the LB service can then be configured within any external services used for request routing, such as a DNS server.

Kontena Services can be linked to any [Kontena Load Balancer](https://kontena.io/docs/using-kontena/loadbalancer) service (services using the `kontena/lb` image) within the same Grid.
The Kontena Master will generate `io.kontena.load_balancer.*` labels for each such linked Service Container.
The Kontena Agent on each Host Node uses the Docker Events API to register any running containers having such labels into the Grid's etcd database.
The etcd database is used by the `kontena/lb` service for dynamic load balancer configuration.

See the [Kontena Load Balancer](https://kontena.io/docs/using-kontena/loadbalancer) documentation for usage documentation.
The [implementation](https://github.com/kontena/kontena-loadbalancer) of the Kontena Load Balancer is based on [HAProxy](http://www.haproxy.org/), using [confd](https://github.com/kelseyhightower/confd) for dynamic configuration.

## DNS Service Discovery

Each Kontena Grid uses Weave DNS for dynamic service discovery of other Service Containers within the same Grid.
Each Service Container is configured with the `kontena.local` search domain, using the local node's `docker0` IP as the DNS resolver.
Within the internal `kontena.local` DNS namespace, each Service Container is registered for both the per-`$container` and per-`$service` names under both the `kontena.local` and `$grid.kontena.local` names.

Applications should be configured using either the short `$service` DNS names resolvable within Service Containers, or using the fully qualified `$service.$grid.kontena.local` names.
This is related to the use of the Kontena VPN service with multiple Grids, and the resolution of the service names within each Grid.
The Kontena [Image Registry](https://kontena.io/docs/using-kontena/image-registry) also uses image names of the form `registry.$grid.kontena.local/myimage`.
The older `$service.kontena.local` names are retained for backwards-compatibility with existing configurations.

Consider the resulting DNS namespace for an example Grid named `testgrid`, with a `testapp/kontena.yml` with 2 instances of service `webservice` and 1 instance of service `db`.

Each of the three containers would have a pair of container names resolving to an internal Grid IP address:

* `testapp-db-1.testgrid.kontena.local` `testapp-db-1.kontena.local`
 * `10.81.1.1`
* `testapp-webservice-1.testgrid.kontena.local` `testapp-webservice-1.kontena.local`
 * `10.81.1.2`
* `testapp-webservice-2.testgrid.kontena.local` `testapp-webservice-2.kontena.local`
 * `10.81.1.3`

Each of the two services would have a pair of service names resolving to multiple IP addresses:

* `testapp-db.testgrid.kontena.local` `testapp-db.kontena.local`
 * `10.81.1.1`
* `testapp-webservice.testgrid.kontena.local` `testapp-webservice.kontena.local`
 * `10.81.1.2`
 * `10.81.1.3`

The `testapp-webservice` service would be configured with the `testapp-db` DNS name, connecting to the running database service instance.
Within the Grid, the `testapp-webservice` name could be used to round-robin requests across the two `webservice` instances.
