---
title: API Reference

language_tabs:
  - http

toc_footers:
  - <a href='https://www.kontena.io/'>Sign Up for a Kontena Account</a>

includes:
  - errors

search: true
---

# Introduction

## API v1 Introduction

Welcome to the Kontena Master API documentation.

The Kontena Master API allows you to manage all things related to Kontena Master in a simple, programmatic way using conventional HTTP requests. The endpoints are intuitive and powerful, allowing you to easily make calls to retrieve information or to execute actions.

All of the functionality that you are familiar with in the Kontena CLI is also available through the API, allowing you to script the complex actions that your situation requires.

The API documentation will start with a general overview about the design and technology that has been implemented, followed by reference information about specific endpoints.

# Authentication

> To authorize, use this code:

```shell
# With shell, you can just pass the correct header with each request
curl "api_endpoint_here"
  -H "Authorization: bearer <access_token>"
```

> Make sure to replace `<access_token>` with your API key.

Kontena Master uses OAuth2 access tokens to allow access to the API. You can generate an permanent access token with Kontena CLI:

`$ kontena master token create --expires-in 0 --token`

See following links for more information about authentication:

- [OAuth2 API](#oauth2)
- [Access Token API](#access-token)
- [Authentication explained](https://www.kontena.io/docs/using-kontena/authentication/)

# Grids

## Grid

```json
{
  "id": "matrix",
  "name": "matrix",
  "initial_size": 3,
  "token": "m118eKZuPLJM/xyb6lA/lQfL6GTi2Upah4arMc4sf5bSLCWnMU9zp0HrXM0cM+B/PS5O7yDZlzg8lPxPwKWDJQ==",
  "stats": {
    "statsd": {
      "server": "10.10.10.2",
      "port": "8121"
    }
  },
  "trusted_subnets": [
    "10.240.0.0/16"
  ]
}
```

A grid is a top level object that describes a group of nodes in a single cluster.

Attribute | Description
---------- | -------
id | A unique identifier for the grid
name | A user provided name
token | A unique token that is automatically generated when the grid is created. Token is shared secret for all the grid nodes
initial_size | Initial (minimum) number of nodes in the grid (initial members are part of etcd cluster)
stats | Statsd export endpoint
trusted_subnets | Array of subnets that can use faster network mode (without encryption)

## List Grids

```http
GET /v1/grids HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Lists all grids that logged in user has access.

### Endpoint

`GET /v1/grids`


## Create a Grid

```http
POST /v1/grids HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Content-Type: application/json
Accept: application/json

{
	"name": "my-grid",
	"initial_size": 3
}
```

Creates a new grid.

### HTTP Request

`POST /v1/grids`

<aside class="notice">
Grid can be only created by users with master_admin role.
</aside>

### JSON Attributes

Attribute | Description
---------- | -------
name | (required) A user provided name
initial_size | Initial (minimum) number of nodes in the grid (initial members are part of etcd cluster)

## Update a Grid

```http
PUT /v1/grids/my-grid HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Content-Type: application/json
Accept: application/json

{
	"trusted_subnets": ["10.240.0.0/16"]
}
```

Updates an existing grid.

### HTTP Request

`PUT /v1/grids/:id`

<aside class="notice">
Only `master_admin` or `grid_admin` roles can modify a grid.
</aside>

### JSON Attributes

Attribute | Description
---------- | -------
stats | Statsd export endpoint
trusted_subnets | Initial (minimum) number of nodes in the grid (initial members are part of etcd cluster)

## Get a Grid

```http
GET /v1/grids/my-grid HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get all the details of a specific grid.

### HTTP Request

`GET /v1/grids/:id`

## Remove a Grid

```http
DELETE /v1/grids/my-grid HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Removes an existing grid.

### HTTP Request

`DELETE /v1/grids/:id`

<aside class="notice">
Only `master_admin` role can remove a grid.
</aside>

## Get Grid stats

```http
GET /v1/grids/my-grid/stats HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get all containers running on the grid with latest statistics (cpu/memory/network usage).  Grid stats are based on container statistics collected with cAdvisor.

### HTTP Request

`GET /v1/grids/:id/stats`

### Query Parameters

Parameter | Description | Default Value
--------- | ------------| -------------
sort | The stat to sort results by (always descending).  Possible values are `cpu` `memory` `rx_bytes` `tx_bytes` | `cpu`



## Get Grid metrics

```http
GET /v1/grids/my-grid/metrics HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Gets aggregated statistics for a grid (cpu, memory, network, disk usage) for a given time frame, returning one statistic per minute.  Memory, network and disk usage values are summed across nodes, cpu is averaged across nodes.  Grid metrics are based on server statistics collected with vmstat.

### HTTP Request

`GET /v1/grids/:id/metrics `

### Query Parameters

Parameter | Description | Default Value
--------- | ------------| -------------
from | The start date and time (example: `?from=2017-01-01T12:15:00.00Z`) | one hour ago
to | The end date and time (example: `?to=2017-01-01T13:15:00.00Z`) | now



## Get Grid container logs

```http
GET /v1/grids/my-grid/container_logs HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get container logs from a grid.

### Endpoint

`GET /v1/grids/{grid_id}/container_logs`

### Query parameters

Parameter | Description
---------- | -------
limit | Limit how many log items are returned
from | Show log items from log id
since | Show log items since (timestamp)
follow | Stream logs

## Get a grid event logs

```http
GET /v1/grids/my-grid/event_logs HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get event logs from a grid.

### Endpoint

`GET /v1/grids/{grid_id}/event_logs`

### Query parameters

Parameter | Description
---------- | -------
limit | Limit how many log items are returned
from | Show log items from log id
since | Show log items since (timestamp)
follow | Stream logs

# Nodes


## Node

```json
{
	"id": "mygrid/misty-sun-87",
	"node_id": "RQKP:Y32W:SB4H:7TNG:5BKC:R6ZO:5B25:C2AV:3Z3Q:SVPX:A76C:WPBX",
	"name": "misty-sun-87",
	"connected": "true",
	"created_at": "",
	"updated_at": "",
	"last_seen_at": "",
	"node_number": 1,
	"initial_node": true,
	"agent_version": "1.0.0",
	"docker_version": "1.11.2",
	"os": "CoreOS 1185.3.0 (MoreOS)",
	"kernel_version": "4.7.3-coreos-r2",
	"driver": "overlay",
	"network_drivers": [
		{"name": "bridge"}, 
		{"name": "host"}, 
		{"name": "null"}
	],
	"volume_drivers": [
		{"name": "local"}
	],
	"cpus": 2,
	"mem_total": 0.0,
	"mem_limit": 0.0,
	"public_ip": "52.30.169.34",
	"private_ip": "172.31.7.179",
	"engine_root_dir": "/var/lib/docker",
	"labels": [
		"region=eu-west-1",
		"az=a",
		"type=m4.large"
	],
	"peer_ips": [
		"172.31.7.172"
	],
	"resource_usage": {
		"memory": {
			"used": 0.0,
			"cached": 0.0,
			"buffers": 0.0,
			"total": 0.0
		},
		"load": {
			"1m": 0.4,
			"5m": 0.3,
			"15m": 0.6
		},
		"filesystem": {
			"name": "docker",
			"used": 0.0,
			"total": 0.0
		},
		"cpu": {
			"usage_pct": 0.0
		},
	    "usage": {
	      "container_seconds": 0
    	}
	},
	"grid": {
		"id": "my-grid",
		"name": "my-grid",
		"initial_size": 3,
		"stats": {
			"statsd": null
		},
		"trusted_subnets": [
			"172.31.0.0/16"
		]
	}
}
```

A node is a virtual or physical machine running Kontena Agent where services can be deployed.


Attribute | Description
---------- | -------
id | A unique id for the node
name | A unique name (within a grid) for the node
connected | Is the node connected to the master (boolean)
node_number | A sequential number for the node
initial_member | Is the node part of initial grid members (boolean)
agent_version | Kontena Agent version running inside the node
docker_version | Docker Engine version in the node
os | Operating system in the node
kernel | Kernel version in the node
driver | Docker filesystem driver
engine_root_dir | Docker engine root directory
cpus | Number of cpu cores in the node
mem_total | Total memory in the node
mem_limit | Memory limit
public_ip | Public ip address
private_ip | Private ip address (used for overlay network communication within a region)
labels | A list of user defined labels for the node
peer_ips | A list of peer ip addresses. Used for creating an overlay network between nodes in the sam grid.
resource_usage | Resource usage stats for the node
grid | A grid object where the node is connected.


## List nodes

```http
GET /v1/grids/my-grid/nodes HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Lists all nodes in a grid.

### Endpoint

`GET /v1/grids/{grid_id}/nodes`

## Update a node

```http
PUT /v1/nodes/mygrid/misty-sun-87 HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json

{
	"labels": ["foo=bar", "bar=baz"]
}
```

Update a node details.

### Endpoint

`PUT /v1/nodes/{node_id}`

## Get a node details

```http
GET /v1/nodes/my-grid/misty-sun-87 HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get a node details.

### Endpoint

`GET /v1/nodes/{node_id}`

## Delete a node

```http
DELETE /v1/nodes/my-grid/misty-sun-87 HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Delete a node from a grid. Does not actually terminate virtual/physical host node, just unregisters node object.

### Endpoint

`DELETE /v1/nodes/{node_id}`

## Get node stats

```http
GET /v1/nodes/my-grid/misty-sun-87/stats HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get all containers running on the node with latest statistics (cpu/memory/network usage).  Node metrics are based on container statistics collected with cAdvisor.

### HTTP Request

`GET /v1/nodes/:grid_id/:id/stats`

### Query Parameters

Parameter | Description | Default Value
--------- | ------------| -------------
sort | The stat to sort results by (always descending).  Possible values are `cpu` `memory` `rx_bytes` `tx_bytes` | `cpu`



## Get node metrics

```http
GET /v1/nodes/my-grid/misty-sun-87/metrics HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Gets aggregated statistics for a node (cpu, memory, network, disk usage) for a given time frame, returning one statistic per minute.  Node metrics are based on server statistics collected with vmstat.

### HTTP Request

`GET /v1/nodes/:grid_id/:id/metrics `

### Query Parameters

Parameter | Description | Default Value
--------- | ------------| -------------
from | The start date and time (example: `?from=2017-01-01T12:15:00.00Z`) | one hour ago
to | The end date and time (example: `?to=2017-01-01T13:15:00.00Z`) | now


# Stacks

## Stack

```json
{
  "id": "my-grid/mongo-replicaset",
  "name": "mongo-replicaset",
  "stack": "kontena/mongo-replicaset",
  "version": "0.1.0",
  "registry": "https://stack-registry.kontena.io",
  "expose": "peer",
  "services": [
  	{
  		"name": "arbiter",
  		"image": "mongo:3.2",
  		"stateful": true,
  		"replicas": 1,
  		"cmd": "--replset kontena --smallfiles",
  		"health_check": {
  			"protocol": "tcp",
  			"port": 27017
  		}
  	},
  	{
  		"name": "peer",
  		"image": "mongo:3.2",
  		"stateful": true,
  		"replicas": 3,
  		"cmd": "--replset kontena --smallfiles",
  		"health_check": {
  			"protocol": "tcp",
  			"port": 27017
  		},
  		"hooks": {
  			"post_start": [
  				{
  					"name": "sleep",
  					"cmd": "sleep 10",
  					"instances": "3",
  					"oneshot": true
  				},
  				{
  					"name": "rs_initiate",
  					"cmd": "mongo --eval \"printjson(rs.initiate());\"",
  					"instances": "3",
  					"oneshot": true
  				},
  				{
  					"name": "rs_add1",
  					"cmd": "mongo --eval \"printjson(rs.add('peer-1'))\"",
  					"instances": "3",
  					"oneshot": true
  				},
  				{
  					"name": "rs_add2",
  					"cmd": "mongo --eval \"printjson(rs.add('peer-2'))\"",
  					"instances": "3",
  					"oneshot": true
  				},
  				{
  					"name": "rs_add_arbited",
  					"cmd": "mongo --eval \"printjson(rs.addArb('arbiter-1'))\"",
  					"instances": "3",
  					"oneshot": true
  				},
  			]
  		}
  	}
  ],
  "volumes": [
    {
      "name": "aVolume",
      "external": "otherName"
    }
  ]
}
```

A stack is a logical grouping of closely related services, that may be linked with one another. A stack can expose a single service to a grid global namespace for other stacks or services to use.

Attribute | Description
---------- | -------
id | A unique id for the stack
name | A unique name (within a grid) for the stack
stack | A name for the stack
version | A version number for the stack
registry | A stack registry where stack schema is originally fetched
expose | A service that stack exposes to grid level DNS namespace
services | A list of stack services (see [services](#services) for more info)
volumes | A list of volumes used in this stack (see [volumes](#volumes) for more info)

### Volume attributes

Attribute | Description
---------- | -------
name  | Name of the volume within the stack
external | Name of the grid level volume definition to use


## Create a stack

```http
POST /v1/grids/my-grid/stacks HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json

{
	"name": "redis",
	"stack": "my/redis",
	"version": "0.1.0",
	"registry": "file://",
	"services": []
}
```

Create a stack.

### Endpoint

`POST /v1/grids/{grid_id}/stacks`

## Modify a stack

```http
PUT /v1/stacks/my-grid/redis HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json

{
	"stack": "my/redis",
	"version": "0.1.1",
	"registry": "file://",
	"services": []
}
```

Modify a stack

### Endpoint

`PUT /v1/stacks/{stack_id}`

## Deploy a stack

```http
POST /v1/stacks/my-grid/redis/deploy HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Deploy a stack. Returns a stack deploy object that can be used for deploy tracking.

### Endpoint

`POST /v1/stacks/{stack_id}/deploy`

## Delete a stack

```http
DELETE /v1/stacks/my-grid/redis HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Delete a stack

### Endpoint

`DELETE /v1/stacks/{stack_id}`

## Get a stack details

```http
GET /v1/stacks/my-grid/redis HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get a stack details.

### Endpoint

`GET /v1/stacks/{stack_id}`

## Get a stack container logs

```http
GET /v1/stacks/my-grid/redis/container_logs HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get container logs from a stack.

### Endpoint

`GET /v1/stacks/{stack_id}/container_logs`

### Query parameters

Parameter | Description
---------- | -------
limit | Limit how many log items are returned
from | Show log items from log id
since | Show log items since (timestamp)
follow | Stream logs

## Get a stack event logs

```http
GET /v1/stacks/my-grid/redis/event_logs HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get event logs from a stack.

### Endpoint

`GET /v1/stacks/{stack_id}/event_logs`

### Query parameters

Parameter | Description
---------- | -------
limit | Limit how many log items are returned
from | Show log items from log id
since | Show log items since (timestamp)
follow | Stream logs

# Services

## Service

```json
{
  "id": "my-grid/redis/redis",
  "name": "redis",
  "created_at": "",
  "updated_at": "",
  "strategy": "ha",
  "state": "running",
  "image": "redis:3.0",
  "affinity": [
    "label=region==eu-west-1"
  ],
  "stateful": true,
  "deploy_opts": {
    "min_health": 0.8,
    "wait_for_port": 6379,
    "interval": null
  },
  "user": "root",
  "replicas": 1,
  "cmd": ["redis"],
  "entrypoint": "/bin/sh",
  "net": "bridge",
  "ports": [],
  "env": [
    "FOO=bar"
  ],
  "secrets": [
    {
      "name": "password",
      "secret": "REDIS_PASSWORD",
      "type": "env"
    }
  ],
  "memory": 1024000000,
  "memory_swap": 4096000000,
  "cpu_shares": 1024,
  "volumes": [
    "/data"
  ],
  "volumes_from": [

  ],
  "cap_add": [
    "NET_ADMIN"
  ],
  "cap_drop": [],
  "links": [],
  "log_driver": "syslog",
  "log_opts": null,
  "hooks": [],
  "health_check": {},
  "instances": {
    "total": 1,
    "running": 1
  }
}
```

A service is a template used to deploy one or more service instances (containers).

Attribute | Description
---------- | -------
id | A unique identifier for the service (composed of grid/stack/service)
name | A user provided name. This name will be inherited by the service instances and will be used in DNS names etc.
image | The image name and tag used for the service
state | Desired state of this service
strategy | Scheduling strategy (default: ha)
affinity | List of affinity rules
instances | How many instances of the services should be deployed
user | Set the user used on instances of this service (will override the image user)
cmd | Container command
entrypoint | Entrypoint to be set on the instances (will override the image entrypoint)
net | Network mode: bridge, host (default: bridge)
ports | Array of exposed ports
env | List of user-defined environment variables to set on the instances of the service (will override the image environment variables)
secrets | Array of mapped secrets from Kontena Vault
memory | Memory limit (excluding optional swap)
memory_swap | Allowed memory (including swap)
cpu_shares | Relative cpu shares (0-1024)
volumes | A list of volumes
volumes_from | A list of volumes to mount from other services
cap_add | List of added capabilities for containers of this service
cap_drop | List of dropped capabilities for containers of this service
links | Links to other services (Array of objects)
log_driver | Log driver (string)
log_opts | Log driver options (object)
hooks | Commands to be executed when service instance is deployed
instance_counts | Stats about how many instances this service currently has

### Deploy Opt attributes

Attribute | Description
--------- | -----------
min_health | -
wait_for_port | -
interval | -

### Health check attributes

Attribute | Description
--------- | -----------
port | The port to use for health check
protocol | The protocol to be used (http or tcp)
interval | How often the health check is performed (in seconds) (default: 10)
initial_delay | The time to wait until the first check is performed after a service instance is created (default: 10)
timeout | How long a response is waited. If no response is received within this timeframe the instance is considered unhealthy.
uri | The relative uri to use for health check (only with http protocol)

### Hook attributes

Attribute | Description
--------- | -----------
name | Hook name
cmd | Command to execute
instances | Specify instances where hook is executed (* or comma separated list of instance numbers)
oneshot | Boolean, if enabled hook is executed only once in a service lifetime

##### Example:

```json
{
	"hooks": {
		"post_start": [
			{
				"name": "hello",
				"cmd": "echo 'hello world'",
				"instances": "*",
				"oneshot": false
			}
		]
	}
}
```

### Link attributes

Attribute | Description
--------- | -----------
name | The linked service. Within stack use `<service_name>`, otherwise use `<stack_name>/<service_name>`
alias | The link alias name

### Port attributes

Attribute | Description
--------- | -----------
ip | The ip where port is exposed (default: 0.0.0.0)
protocol | The protocol of the port (default: tcp)
node_port | The published port in the node network interface
container_port | The published port inside the container

### Secret attributes

Attribute | Description
--------- | -----------
secret | Secret name in the Kontena Vault
name | Service local name for the secret
type | How secret is exposed to a service container

## List services

```http
GET /v1/grids/my-grid/services HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Lists all services in a grid.

### Endpoint

`GET /v1/grids/{grid_id}/services`

## Create a service

```http
POST /v1/grids/my-grid/services HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{
	"name": "redis",
	"image": "redis:3.0",
	"stateful": true
}
```

Creates a service to a grid.

### Endpoint

`POST /v1/grids/{grid_id}/services`

## Update a service

```http
PUT /v1/services/my-grid/null/redis HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{
	"image": "redis:3.2"
}
```

Creates a service to a grid.

### Endpoint

`PUT /v1/services/{service_id}`

## Deploy a service

```http
POST /v1/services/my-grid/null/redis/deploy HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{}
```

Deploys a service. Response is a json object that contains deployment id that can be tracked.

### Endpoint

`POST /v1/services/{service_id}/deploy`

## Start a service

```http
POST /v1/services/my-grid/null/redis/start HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{}
```

Sends a start signal to the service instances and changes the service desired state to running.

### Endpoint

`POST /v1/services/{service_id}/start`

## Restart a service

```http
POST /v1/services/my-grid/null/redis/restart HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{}
```

Sends a restart signal to the service instances.

### Endpoint

`POST /v1/services/{service_id}/restart`

## Stop a service

```http
POST /v1/services/my-grid/null/redis/stop HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{}
```

Sends a stop signal to the service instances and changes the service desired state to stopped.

### Endpoint

`POST /v1/services/{service_id}/restart`

## Scale a service

```http
POST /v1/services/my-grid/null/redis/scale HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{
	"instances": 5
}
```

Scales services instances to given number. Returns a json object that contains deploy id that can be tracked.

### Endpoint

`POST /v1/services/{service_id}/scale`

## Delete a service

```http
DELETE /v1/services/my-grid/null/redis HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Removes the service from the grid.

### Endpoint

`DELETE /v1/services/{service_id}`

## Get service container logs

```http
GET /v1/services/my-grid/null/redis/container_logs HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get container logs from a service.

### Endpoint

`GET /v1/services/{service_id}/container_logs`

### Query parameters

Parameter | Description
---------- | -------
limit | Limit how many log items are returned
from | Show log items from log id
since | Show log items since (timestamp)
follow | Stream logs

## Get service event logs

```http
GET /v1/services/my-grid/null/redis/event_logs HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get event logs from a service.

### Endpoint

`GET /v1/services/{service_id}/event_logs`

### Query parameters

Parameter | Description
---------- | -------
limit | Limit how many log items are returned
from | Show log items from log id
since | Show log items since (timestamp)
follow | Stream logs

## Get a service deploy

```http
GET /v1/services/my-grid/null/redis/deploys/893723489789 HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Removes the service from the grid.

### Endpoint

`DELETE /v1/services/{service_id}`

## Get service stats

```http
GET /v1/services/my-grid/null/redis/stats HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get all containers belonging to the service with latest statistics (cpu/memory/network usage).  Service stats are based on container statistics collected with cAdvisor.

### HTTP Request

`GET /v1/services/:grid_id/:stack_id/:id/stats`

### Query Parameters

Parameter | Description | Default Value
--------- | ------------| -------------
sort | The stat to sort results by (always descending).  Possible values are `cpu` `memory` `rx_bytes` `tx_bytes` | `cpu`



## Get service metrics

```http
GET /v1/services/my-grid/null/redis/metrics HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Gets aggregated statistics for a service (cpu, memory, network) for a given time frame, returning one statistic per minute.  Service metrics are based on container statistics collected with cAdvisor.

### HTTP Request

`GET /v1/services/:grid_id/:stack_id/:id/metrics`

### Query Parameters

Parameter | Description | Default Value
--------- | ------------| -------------
from | The start date and time (example: `?from=2017-01-01T12:15:00.00Z`) | one hour ago
to | The end date and time (example: `?to=2017-01-01T13:15:00.00Z`) | now

# Secrets

## Secret

```json
{
	"id": "my-grid/SECRET_PWD",
	"name": "SECRET_PWD",
	"created_at": "",
	"value": "T0Ps3crT"
}
```

Attribute | Description
--------- | -----------
id | An unique id for the secret
created_at | A timestamp when the secret was created
name | A name for the secret (unique within a grid)
value | A value for the secret (encrypted in the database)

## List secrets

```http
GET /v1/services/my-grid/secrets HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

List all secrets in a grid.

### Endpoint

`GET /v1/grids/{grid_id}/secrets`

## Create a secret

```http
POST /v1/services/my-grid/secrets HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{
	"name": "SECRET_PWD",
	"value": "T0Ps3crT"
}
```

Create a secret.

### Endpoint

`POST /v1/grids/{grid_id}/secrets`


## Update a secret

```http
PUT /v1/secrets/my-grid/SECRET_PWD HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{
	"value": "T0Ps3crT",
	"upsert": false
}
```

Update (or upsert) a secret.

### Endpoint

`PUT /v1/secrets/{secret_id}`


## Read a secret

```http
GET /v1/secrets/my-grid/SECRET_PWD HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Read a secret.

### Endpoint

`GET /v1/secrets/{secret_id}`

## Delete a secret

```http
DELETE /v1/secrets/my-grid/SECRET_PWD HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Delete a secret.

### Endpoint

`DELETE /v1/secrets/{secret_id}`

# External Registries

## External Registry

```json
{
	"id": "my-grid/registry.domain.com",
	"name": "registry.domain.com",
	"url": "https://registry.domain.com/",
	"username": "a_bot",
	"email": "a_bot@domain.com"
}
```

## List external registries

```http
GET /v1/grids/my-grid/external_registries HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

List external registries in a grid.

### Endpoint

`GET /v1/grids/{grid_id}/external_registries`

## Create an external registry

```http
POST /v1/grids/my-grid/external_registries HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{
	"url": "https://registry.domain.com/",
	"username": "a_bot",
	"email": "a_bot@domain.com",
	"password": "xyz123"
}
```

Create an external registry.

### Endpoint

`POST /v1/grids/{grid_id}/external_registries`

## Delete an external registry

```http
DELETE /v1/external_registries/my-grid/registry.domain.com HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Create an external registry.

### Endpoint

`DELETE /v1/grids/{grid_id}/external_registries`

# Certificates

Let's Encrypt certificate management.

## Register email to Let's Encrypt

```http
POST /v1/certificates/my-grid/register HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{
	"email": "john.doe@domain.com"
}
```

Register email to Let's Encrypt.

### Endpoint

`POST /v1/certificates/{grid_id}/register`

## Authorize a domain

```http
POST /v1/certificates/my-grid/authorize HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{
	"domain": "foo.domain.com"
}
```

Authorize a domain with Let's Encrypt.


Returns a dns challenge:

Attribute | Description
--------- | -----------
record_name | A record name for the given domain
record_type | A record type for the given domain
record_content | A record content for the given domain

### Endpoint

`POST /v1/certificates/{grid_id}/authorize`

## Create a certificate

```http
POST /v1/certificates/my-grid/certificate HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{
	"secret_name": "FOO_DOMAIN_COM",
	"domains": ["foo.domain.com"],
	"cert_type": "fullchain"
}
```

Create a certificate for the authorized domains. Certificates are written automatically to the Kontena Vault (see [secrets](#secrets) api). The secret name attribute is used as a prefix for the actual secret items.

For example `"secret_name": "FOO_DOMAIN_COM"` will write following secrets to the Kontena Vault:

- `FOO_DOMAIN_COM_PRIVATE_KEY`
- `FOO_DOMAIN_COM_CERTIFICATE`
- `FOO_DOMAIN_COM_BUNDLE`

### Endpoint

`POST /v1/certificates/{grid_id}/certificate`

# Volumes

**Volumes support is at experimental state which means that there might be breaking changes between versions until the experimental status is removed.**

## Volume

```json
{
  "id": "my-grid/foo",
  "name": "foo",
  "scope":"instance",
  "driver":"local",
  "driver_opts": {
    "driver_specific_option": "foobar",
    "another_option": "xyz"
  },
  "instances": [
    {
      "name":"stack.svc.foo-1",
      "node": "node-1"
    }
  ],
  "services": [
    {
      "id":"my-grid/stack/svc"
    }
  ]
}
```

Attribute | Description
--------- | -----------
name      | Name of the volume
scope     | Scope for the volume (`instance`, `stack` or `grid`)
driver    | Volume driver to be used. Each node reports it's supported drivers, see [node details](#get-a-node-details)
driver_opts| Options for the volume driver

## List volumes

Lists volumes created to a grid

```http
GET /v1/volumes/{grid_id} HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

### Endpoint

`GET /v1/volumes/{grid_id}`

## Create a volume

```http
POST /v1/volumes/{grid_id} HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json

{
  "name":"foo",
  "scope":"instance",
  "driver":"local",
  "driver_opts": {
    "driver_specific_option": "foobar",
    "another_option": "xyz"
  }
}
```

Creates a volume to a grid

### Endpoint

`POST /v1/volumes/{grid_id}`

## Delete a volume

```http
DELETE /v1/volumes/{volume_id} HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```
### Endpoint

`DELETE /v1/volumes/{volume_id}`

# Configuration

## Configuration

```json
{
	"config.key.name": "value",
	"config.another.name": "another_value"
}
```

Kontena Master configuration object.

## Show configuration

```http
GET /v1/config HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get the configuration object.

### Endpoint

`GET /v1/config`


## Update configuration

```http
PATCH /v1/config HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{
	"foo.bar": "bar",
	"bar.baz": "baz"
}
```

Update/upsert configuration key-value pairs.

### Endpoint

`PATCH /v1/config`

## Replace configuration

```http
PUT /v1/config HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
Content-Type: application/json

{
	"foo.bar": "bar",
	"bar.baz": "baz"
}
```

Replace whole configuration object with key-value pairs.

### Endpoint

`PUT /v1/config`

# OAuth2

## Authenticate to authentication provider

```http
GET /oauth2/authenticate HTTP/1.1
Accept: application/json
redirect_uri=http://localhost:5177/&invite_code=98afydaggf
```

Create an authorization request for an invite code. Redirects to the configured authentication provider authorization url.

### Endpoint

`GET /oauth2/authenticate`


## Token

```http
POST /oauth2/token HTTP/1.1
Accept: application/json
grant_type=authorization_code&code=s8dyf9sd8fy9sd8yfa
```

Standard OAuth2 token endpoint. Returns an [access token](#access-token).

### Endpoint

`POST /oauth2/token`

## Authorization callback

```http
GET /cb HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json

code=s8d9f9sd8yfsdy&state=s89dfs98dfys8d9fy
```

Standard OAuth2 authorization callback endpoint. Redirects back to authorization request redirect_uri.

### Endpoint

`GET /cb`

### Query parameters

Attribute | Description
--------- | -----------
state | OAuth2 code request


## Create authorization

```http
POST /oauth2/authorize HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json

response_type=access_token&expires_in=7200
```

Standard OAuth2 authorize endpoint. Create access token or code.

### Endpoint

`POST /oauth2/authorize`


# Access Tokens

## Access Token

```json
{
	"id": "09348203840328023948",
	"token_type": "bearer",
	"access_token_last_four": "dufy",
	"refresh_token_last_four": "isdf",
	"expires_in": 7200,
	"scopes": "user",
	"user": {
		"id": "987983749274",
		"email": "john.doe@domain.com",
		"name": "john"
	}
}
```

Attribute | Description
--------- | -----------
id | A unique id for token
token_type | OAuth2 token type
access_token_last_four | last four chars of access_token
refresh_token_last_four | last four chars of refresh token
expires_in | Time in seconds until the access token expires
scopes | A comma separated list of access token scopes
user | A user that owns the access token

## List access tokens

```http
GET /oauth2/tokens HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

List access tokens that belong to current user.

### Endpoint

`GET /oauth2/tokens`

## Get access token details

```http
GET /oauth2/tokens/09348203840328023948 HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Get an access token details.

### Endpoint

`GET /oauth2/tokens/{access_token_id}`

## Delete access token

```http
DELETE /oauth2/tokens/09348203840328023948 HTTP/1.1
Authorization: bearer 8dqAd30DRrzzhJzbcSCG0Lb35csy5w0oNeT+8eDh4q2/NTeK3CmwMHuH4axcaxya+aNfSy1XMsqHP/NsTNy6mg==
Accept: application/json
```

Delete an access token.

### Endpoint

`DELETE /oauth2/tokens/{access_token_id}`
