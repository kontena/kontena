---
title: Users
---

# Users

Kontena has built-in role-based user management. The first user that logs in to Kontena Master will be assigned to the  `master_admin` role. The Master admin can invite new users to the Master server and assign users to the `master_admin` or `grid_admin` roles. The Master admin and Grid admin can add and remove users from a Grid.


## Roles

**master_admin**
  * can invite users to Kontena Master
  * can manage user roles
  * can manage all Grids and their users

**grid_admin**
  * can manage Grid users

**user**
  * can only operate within Grids

The user role is automatically assigned to any user added to a Grid using the [Add User to Grid](users#add-user-to-grid) command. There is no need to assign the role explicitly in this case.

## Managing Users

* [Register a New Account](users#register-a-new-kontena-account)
* [Invite user to Kontena Master](users#invite-user-to-kontena-master)
* [Add Users to Role](users#add-users-to-role)
* [Remove Users from Role](users#remove-users-from-role)
* [Add User to Grid](users#add-user-to-grid)
* [Remove User from Grid](users#remove-user-from-grid)
* [Remove User from Kontena Master](users#remove-user-from-kontena-master)

### Invite User to Kontena Master

```
$ kontena master user invite <email>
```

### Add Users to Role

```
$ kontena master user role add <role> <email>
```

### Remove Users from Role

```
$ kontena master user role remove <role> <email>
```

### Add User to Grid

```
$ kontena grid user add <email>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Remove User from Grid

```
$ kontena grid user remove <email>
```

**Options:**

```
--grid GRID                   Specify Grid to use
```

### Remove User from Kontena Master

```
$ kontena master user remove <email>
```
