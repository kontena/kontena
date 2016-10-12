# Network Model

Kontena's network model is based on the **Grid**, spanning a set of host **Nodes**.
The Grid provides connectivity between Service **Containers** on different Nodes.

Each host Node is a separate virtual machine, which can have some combination of **Public** and **Private** network addresses.
Nodes within the same region can communicate using their Private network address.
The Public network address can be used to access network services exposed by the Node.

Each Grid has a single **Overlay Network** using private RFC1918 address space.
The Kontena Agent establishes the Overlay Network mesh between the Nodes.
Nodes and Containers are connected to the overlay network.
Nodes and Containers can use their *overlay* network address to communicate within the Grid.

Each host Node runs the Kontena **Agent**, which establishes a WebSocket connection to a **Master** node running the Kontena **Server**.
The host Node's Kontena Agent and the Master node are only used for cluster management. The Master node is not connected to the Grid, and Containers attached to the Grid cannot communicate with the Kontena Master.
The Master Node does not expose any network services other than the HTTP API used by the CLI and Agent.

While a Kontena master can manage multiple Grids, each Grid is an isolated overlay network with its own address space.
Nodes and Containers attached to different Grids cannot communicate.

## Grid

Each grid has a single overlay network. The default overlay network used is `10.81.0.0/19`, and it currently cannot be configured at creation time nor changed later.

Each Grid may also include a set of Trusted Subnets, which are used for the Overlay Networking described further below.

### IP Address Management

Overlay network addresses are allocated by the Kontena Master, which tracks each allocated overlay network address.
Using the default address allocation scheme, each Grid can contain up to 254 Host Nodes, and 8190 Service Containers.

When a Host Node's Kontena Agent is disconnected from the Kontena Master, the overlay network addresses used by the Node's Containers are released.
Released overlay network addresses may be used for new Service Containers being deployed.

If a disconnected host Node reconnects, the overlay network addresses of any returning Service containers are restored.
In case of a conflict where the overlay network address has been reallocated for a second Service Container after the original Node disconnected, the reallocated overlay network address is released, and the second Service Container is re-deployed.

## Host Node

A host Node is a (virtual) machine running the Docker Engine and Kontena Agent.
The Kontena Agent runs as a Docker container, and controls the Docker Engine to manage infrastructure Containers and Service Containers.

Each Node can be be assigned to a Region using a Docker Engine `region=` label.
The Node Region is string value (provided by the provisioning plugin) that is compared against other Nodes' Regions to determine if they share an internal network.

### Node Network Addresses
Each host Node has a total of four different network addresses:

* `public_ip`: The external Internal address of the machine.

  The public network address is resolved using the `http://whatismyip.akamai.com` service, or it can be configured using `KONTENA_PUBLIC_IP`.

  The public addess can be used to connect to network services exposed on the host Node, including the Weave service used for the overlay network, and those Service Containers with published ports.
  For a node behind NAT, such as a Vagrant node, the public address may not necessarily work for incoming connections.

* `private_ip`: The internal regional address of the machine.

  The private network address is resolved using the interface address configured on the internal interface, or it can be configured using `KONTENA_PRIVATE_IP`.
  The internal interface is `eth1`, or the interface given by `KONTENA_PEER_INTERFACE`.
  If the internal interface does not exist, the address on the `eth0` interface is used.

  For two nodes within the same region, the private address is used for node-to-node communication in place of the public address.

* The overlay network address (`10.81.0.x`).

  Each Host Node within a Grid is assigned a sequential Node Number, in the range of `1..254`.

  Once the overlay network has been established, the host machine is also configured with a statically allocated overlay network address based on the sequentially assigned Node number.

  The Node's overlay network address is used for the Grid's infrastructure services, including Kontena's etcd cluster.
  Any Kontena Service container can connect to the host Node's overlay network address.

* The Docker gateway address (`172.17.0.1` on `docker0`)

  Each Host Node uses the Docker default bridge network to provide Containers with access to the internal network.

  The Docker gateway address is a also used as the DNS resolver for the Containers, provided by Weave DNS.

### Node Infrastructure Services
Each host Node runs a number of infrastructure services as Docker containers, using the host network namespace.

| Service   | Protocol | Port | Addresses                 | Description
|-----------|----------|------|---------------------------|-----------------------
| Weave DNS | TCP+UDP  | 53   | `172.17.0.1` (`docker0`)  | Weave DNS
| etcd      | TCP      | 2379 | <ul><li>`127.0.0.1` (`lo`)</li><li>`172.17.0.1` (`docker0`)</li><li>`10.81.0.X` (weave)</li></ul> | etcd Clients
| etcd      | TCP      | 2380 | `10.8.10.X` (weave)       | etcd Peers
| Weave Net | TCP      | 6783 | `*`                       | Weave Net Control
| Weave Net | UDP      | 6783 | `*`                       | Weave Net Data (`sleeve`)
| Weave Net | UDP      | 6784 | `*`                       | Weave Net Data (`fastdp`)

Only the Weave Net service is externally accessible, which is required for forming the Overlay Network mesh between host Nodes.

## Overlay Network

At startup, the Kontena Agent establishes the overlay network mesh between the Grid's Nodes.
The overlay network mesh is used to bootstrap the Grid infrastructure, as the host Node's overlay network address is used for infrastructure services such as etcd.

The overlay network is established using the network addresses of the peer Nodes within the Grid, which the Agent receives from the Master at startup.
The overlay network mesh uses the Private network address of a peer node within the same Region, otherwise the Public network address is used.
Once the overlay network is started, the host Node's overlay network address is configured using [`weave expose`](https://www.weave.works/docs/net/latest/using-weave/host-network-integration/).

The overlay network is powered by Weave Net, using [Weave's encrypted `sleeve` tunnels](https://www.weave.works/docs/net/latest/using-weave/security-untrusted-networks/) to form a flat Layer 2 network spanning all Grid Nodes and connected Containers.

Alternatively, [Weave's Fast Datapath](https://www.weave.works/docs/net/latest/using-weave/fastdp/) can be used for traffic between Nodes within the Grid's Trusted Subnets.
Using Trusted Subnets and Weave's Fast Datapath provides [improved performance](https://www.weave.works/weave-docker-networking-performance-fast-data-path/) at the cost of a lack of data plane encryption between Nodes.

## Service Containers

The Service Containers are created using the default Docker bridge network, which provides each Container with an isolated network namespace.
The default Docker bridge network is used to provide the Container with a default route for connecting to external services, using SNAT on the host machine.
The Docker bridge network is local to each Node, and Containers on different nodes will have overlapping local Docker bridge networks.

Each Service Container being started is also attached to the Weave network.
The Container's `ethwe` network interface is used for the internal communication between Grid Services, using the Overlay Network's `10.81.0.0/17` subnet.

In order to avoid any issues with Container services attempting to resolve or connect to other services on the overlay network, the `weavewait` utility is used to delay the Container service execution until the Container's Weave network is ready.
This uses a modified Docker entrypoint for the Container.

## Publishing Services

Every Service Container will automatically be internally accessible via the Grid from other host Nodes and Service Containers.
Accessing any Service externally requires the Service's ports to be explicitly published, using a list of published TCP and UDP ports, configured in the `kontena.yml`.
These are deployed as published container ports on the Docker default bridge network, using DNAT on the host machine to provide external access to the published services.

The host Node's public (and private) addresses can be used to access those services published by Service Containers running on that Node.
Only one Service can publish any given port on a given Node.
The ports used for infrastructure services on the hsot Nodes cannot be used to publish other services.

### Kontena Load Balancer
The Kontena Load Balancer can also be used to provide external access to TCP and HTTP services, including dynamic load-balancing of multiple Service Container backends.

See the [Kontena Load Balancer](https://kontena.io/docs/using-kontena/loadbalancer) documentation for configuration details.

The [implementation](https://github.com/kontena/kontena-loadbalancer) of the Kontena Load Balancer is based on [haproxy](http://www.haproxy.org/), using [confd](https://github.com/kelseyhightower/confd) for dynamic configuration.
The Kontena Agent is responsible for updating running services into etcd.

## DNS (`kontena.local`)

Each Kontena Grid uses Weave DNS for dynamic service discovery of other service containers within the same grid.
Each Service Container is configured with the `kontena.local` search domain, using the local node's `docker0` IP as the DNS resolver.
Within the internal `kontena.local` DNS namespace, each Service Container is registered for both the per-container and per-service names under both the `kontena.local` and `$grid.kontena.local` names.

The `kontena.local` names are deprecated and the `$grid.kontena.local` names should be used instead.
This is related to the use of the Kontena VPN service with multiple grids, and being able to resolve the service names within each such grid.
The Kontena [Image Registry](/docs/using-kontena/image-registry) also uses image names of the form `registry.$grid.kontena.local/myimage`.

Consider the resulting DNS namespace for an example Grid named `testgrid`, with an `testapp/kontena.yml` with 2 instances of service `webservice` and 1 instance of service `db`.

Each of the three container would have a pair of container names resolving to an internal Grid IP address:

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
