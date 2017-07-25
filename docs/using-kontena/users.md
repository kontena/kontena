---
title: Users
---

# Users

Kontena uses roles to grant access to specific grid operations to master users.
New Kontena masters are initially provisioned with a local `admin` user using the `INITIAL_ADMIN_CODE`, which can be used to invite other users and grant them roles.
Users with the `master_admin` role are equivalent to the initial `admin` user, and other more specific roles can be used grant more limited access.

The Kontena master API uses OAuth2 tokens for [Authentication](`authentication`), and users are identified by email address. The default OAuth2 provider for plugin-provisioned masters is the [Kontena Cloud](authentication#configuring-kontena-cloud-as-the-authentication-provider).

Each user belongs to a specific list of grids, and users can only list and access grids that they belong to.
The local `admin` user and `master_admin` role can access any grids.
Kontena roles are assigned to users, and apply to any grids that the user is a member of.
By default, users only have access to the secrets, volumes, stacks, services etc. within a grid.

## Roles

### `master_admin`
  * All `users_admin` permissions
  * Add and remove user roles
  * Manage grids (create, remove)
  * All `grid_admin` permissions for all grids

### `users_admin`
  * Invite and remove users
  * Manage grid users (only user grids)

### `grid_admin`

  * Manage grid (update)
  * Manage grid users
  * Manage grid host nodes (create, reset tokens)
  * All grid user permissions

### Grid user without any roles

  * Manage grid secrets, services, stacks, volumes etc.

The grid user permissions are automatically granted for any user added to a Grid using the [Add User to Grid](users#add-user-to-grid) command. There is no need to assign any explicit role for this case.

## Managing Users

* [Register a New Account](users#register-a-new-kontena-account)
* [Invite user to Kontena Master](users#invite-user-to-kontena-master)
* [Add Users to Role](users#add-users-to-role)
* [Remove Users from Role](users#remove-users-from-role)
* [Add User to Grid](users#add-user-to-grid)
* [Remove User from Grid](users#remove-user-from-grid)
* [Remove User from Kontena Master](users#remove-user-from-kontena-master)

### Register a new Kontena Account

Use the configured OAuth2 [Authentication](`authentication`) provider to register: https://cloud.kontena.io/

### Invite User to Kontena Master

```
$ kontena master user invite <email>
```

Requires `users_admin` role.

### Add Users to Role

```
$ kontena master user role add <role> <email>
```

Requires `master_admin` role.

### Remove Users from Role

```
$ kontena master user role remove <role> <email>
```

Requires `master_admin` role.

### Add User to Grid

```
$ kontena grid user add <email>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

Requires `users_admin` or `grid_admin` role.

### Remove User from Grid

```
$ kontena grid user remove <email>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

Requires `users_admin` or `grid_admin` role.


### Remove User from Kontena Master

```
$ kontena master user remove <email>
```

Requires `users_admin` role.
