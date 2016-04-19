---
title: Users
toc_order: 1
---

# Users

Kontena has built-in role based user management. The first user that logs in to Kontena Master will be assigned to `master_admin` role. Master admin can invite new users to Master server and assign users to `master_admin` or `grid_admin` roles. Master admin and grid admin can add and remove users from grid.


## Roles

**master_admin**
  * can invite users to master server
  * can manage user roles
  * can manage all grids and their users

**grid_admin**
  * can manage grid users

**user**
  * can only operate within grids

## Managing Users

* [Register a New Account](users#register-a-new-kontena-account)
* [Invite user to Kontena Master](users#invite-user-to-kontena-master)
* [Add Users to Role](users#add-users-to-role)
* [Remove Users from Role](users#remove-users-from-role)
* [Add User to Grid](users#add-users-to-role)
* [Remove User from Grid](users#remove-user-from-grid)
* [Remove User from Kontena Master](users#remove-user-from-kontena-master)

### Register a New Kontena Account

```
$ kontena register
```

**Options:**

```
--auth-provider-url AUTH_PROVIDER_URL Auth provider URL
```

### Invite User to Kontena Master

```
$ kontena master users invite <email>
```

### Add Users to Role

```
$ kontena master users add-role <role> <email>
```

### Remove Users from Role

```
$ kontena master users remove-role <role> <email>
```

### Add User to Grid

```
$ kontena grid add-user <email>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Remove User from Grid

```
$ kontena grid remove-user <email>
```

**Options:**

```
--grid GRID                   Specify grid to use
```

### Remove User from Kontena Master

```
$ kontena master users remove <email>
```
