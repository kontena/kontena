---
title: Users
toc_order: 1
---

Kontena has built-in role based user management. The first user that logs in to Kontena Master will be assigned to `master_admin` role. Master admin can invite new users to Master server and assign users to `master_admin` or `grid_admin` roles. Master admin and grid admin can add and remove users from grid.

Kontena has the following commands to manage users:

# Users

## Register a New Kontena Account

```
$ kontena register
```

## Invite User to Kontena Master

```
$ kontena master users invite <email>
```

## Add users to role

```
$ kontena master users add-role <role> <email>
```

## Remove users from role

```
$ kontena master users remove-role <role> <email>
```

## Add User to Grid

```
$ kontena grid add-user <email>
```

## Remove User from Grid

```
$ kontena grid remove-user <email>
```
