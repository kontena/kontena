---
title: Grids
---

# Grids

The [Grid](../core-concepts/architecture.md#the-grid) is a top-level object in Kontena that describes a single cluster of Kontena Nodes.

* [Manage](grids.md#manage-grids)
* [Logs](grids.md#grid-logs)
* [Users](grids.md#grid-users)
* [Trusted Subnets](grids.md#grid-trusted-subnets)

### Manage Grids

#### Create a New Grid

```
$ kontena grid create --initial-size=3 mygrid
```

Creates a new Grid named `mygrid` with initial size of three Nodes (the Grid must have at least three nodes that are part of an etcd cluster). Etcd member nodes create the actual data cluster and rest of the Grid nodes act as `proxy` nodes for etcd. Typically you want to spread your Grid nodes between different availability zones so that losing the majority of the initial nodes becomes virtually impossible. Losing the majority impairs etcd and will cause troubles within the Kontena Grid in areas such as service load balancing.

Starting with Kontena version 0.14.0, Kontena can automatically replace the initial etcd cluster members as long as there has NOT been a majority loss. In practice this means that you can replace the initial members by removing them (while keeping the majority) and replacing with new nodes.


#### List Grids

```
$ kontena grid list
```

#### Switch to Grid

```
$ kontena grid use another_grid
```

Switches cli scope to a Grid named `another_grid`.

#### Remove a Grid

```
$ kontena grid remove mygrid

```

Removes a Grid named `mygrid`.

#### Show Current Grid

```
$ kontena grid current
```

Shows currently used Grid details.

### Grid Logs

#### Show Current Grid Logs

```
$ kontena grid logs
```

#### Show Current Grid Audit Log

```
$ kontena grid audit-log
```

### Show Current Grid Environment Details

```
$ kontena grid env
```

### Show Current Grid Cloud-Config

```
$ kontena grid cloud-config
```

### Grid Users

#### List Current Grid Users

```
$ kontena grid user list
```

#### Add User to the Current Grid

```
$ kontena grid user add not@val.id
```

Adds user with email `not@val.id` to the current Grid. Note: user has to be invited to Kontena Master first.

#### Remove a User from the Current Grid

```
$ kontena grid user remove not@val.id
```

Removes a user with an email `not@val.id` from the current grid.

### Grid Trusted Subnets

If some of the Grid nodes are colocated in a trusted network (for example, within the boundary of your own datacenter) you can add subnets to a Grid's trusted subnet list. This disables data plane encryption within a trusted subnet and switches overlay to faster (near-native) mode as an optimization.

#### List Trusted Subnets

```
$ kontena grid trusted-subnet ls
```

#### Add Trusted Subnet

```
$ kontena grid trusted-subnet add <grid> <subnet>
```

#### Remove Trusted Subnet

```
$ kontena grid trusted-subnet remove <grid> <subnet>
```
