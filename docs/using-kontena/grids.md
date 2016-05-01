---
title: Grids
toc_order: 2
---

# Grids

The [Grid](../core-concepts/architecture.md#the-grid) is top-level object in Kontena that describes a single cluster of Kontena Nodes.

* [Manage](grids#manage-grids)
* [Logs](grids#grid-logs)
* [Users](grids#grid-users)
* [Trusted Subnets](grids#grid-trusted-subnets)

### Manage Grids

#### Create a New Grid

```
$ kontena grid create --initial-size=3 mygrid
```

Creates a new grid named `mygrid` with initial size of 3 nodes (grid must have at least 3 nodes that are part of etcd cluster).

#### List Grids

```
$ kontena grid list
```

#### Switch to Grid

```
$ kontena grid use another_grid
```

Switches cli scope to grid named `another_grid`.

#### Remove a Grid

```
$ kontena grid remove mygrid

```

Removes a grid named `mygrid`.

#### Show Current Grid

```
$ kontena grid current
```

Shows currently used grid details.

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
$ kontena grid list-users
```

#### Add User to the Current Grid

```
$ kontena grid add-user not@val.id
```

Adds user with email `not@val.id` to the current grid. Note: user has to be invited to master first.

#### Remove a User from the Current Grid

```
$ kontena grid remove-user not@val.id
```

Removes a user with an email `not@val.id` from the current grid.

### Grid Trusted Subnets

If some of grid nodes are colocated in a trusted network (for example within the boundary of your own datacenter) you can add subnets to grid trusted subnet list. This disables data plane encryption within trusted subnet and switches overlay to faster (near-native) mode as an optimization.

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
