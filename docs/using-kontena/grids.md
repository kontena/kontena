---
title: Grids
toc_order: 2
---

# Grids

The [Grid](../core-concepts/architecture.md#the-grid) is top-level object in Kontena that describes a single cluster of Kontena Nodes.

## Create a New Grid

```
$ kontena grid create --initial-size=3 mygrid
```

Creates a new grid named `mygrid` with initial size of 3 nodes (grid must have at least 3 nodes that are part of etcd cluster).

## List Grids

```
$ kontena grid list
```

## Switch to Grid

```
$ kontena grid use another_grid
```

Switches cli scope to grid named `another_grid`.

## Show Current Grid

```
$ kontena grid current
```

Shows currently used grid details.
