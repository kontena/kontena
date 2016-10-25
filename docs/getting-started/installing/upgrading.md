---
title: Upgrading
---

# Upgrading Kontena from Previous Versions

Upgrading Kontena is easy. Usually it's enough to just update Kontena Master
and the nodes will follow automatically (if an upgrade is required). Cli updates
can be installed via rubygems.

## Versions

* [0.15 to 0.16 (latest)](upgrading#upgrading-from-0-15-to-0-16)
* [0.14 to 0.15](upgrading#upgrading-from-0-14-to-0-15)
* [0.13 to 0.14](upgrading#upgrading-from-0-13-to-0-14)
* [0.12 to 0.13](upgrading#upgrading-from-0-12-to-0-13)
* [0.11 to 0.12](upgrading#upgrading-from-0-11-to-0-12)
* [0.10 to 0.11](upgrading#upgrading-from-0-10-to-0-11)
* [0.9 to 0.10](upgrading#upgrading-from-0-9-to-0-10)
* [0.8 to 0.9](upgrading#upgrading-from-0-8-to-9)

### Upgrading from 0.15 to 0.16

** Official Installation Method**

- restart master:

```
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

- update cli:

```
$ gem install kontena-cli
```

** Custom Installs**
- update master, agent and cli to 0.16

** Migration steps **

Kontena Master is using oauth2 based authentication starting from 0.16 release. When migrating to this release the new oauth2 setting have to be created for the master. This can be done with following steps after master is updated:
- update cli to 0.16
- login to Kontena Cloud by issuing `kontena cloud login`
  - For this you need an account in [Kontena Cloud](https://cloud.kontena.io)
  - Use the same email as you've been using previously with Kontena to allow smooth transition to new oauth2 based authentication.
- Run `kontena master init-cloud` that will automatically configure your master to use new oauth2 mechanism.
  > After this:
  > * Users will not be able to reauthenticate without authorizing the
  > Master to access their Kontena Cloud user information
  > * Users that have registered a different email address to Kontena
  > Cloud than the one they currently have as their username in the
  > master will not be able to authenticate before an administrator
  > of the Kontena Master creates an invitation code for them.

- If you or other users are using different email than previously you have to invite them to use the master:
  `kontena master users invite john.doe@example.com`


### Upgrading from 0.14 to 0.15

** Official Installation Method**

- restart master:

```
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

- update cli:

```
$ gem install kontena-cli
```

** Custom Installs**
- update master, agent and cli to 0.15

### Upgrading from 0.13 to 0.14

** Official Installation Method**

- restart master:

```
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

- update cli:

```
$ gem install kontena-cli
```

** Custom Installs**
- update master, agent and cli to 0.14


### Upgrading from 0.12 to 0.13

** Official Installation Method**

- restart master:

```
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

- update cli:

```
$ gem install kontena-cli
```

** Custom Installs**
- update master, agent and cli to 0.13

### Upgrading from 0.11 to 0.12

** Official Installation Method**

- restart master:

```
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

- update cli:

```
$ gem install kontena-cli:0.12
```

** Custom Installs**
- update master, agent and cli to 0.12

### Upgrading from 0.10 to 0.11

** Official Installation Method**

- restart master:

```
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

- update cli:

```
$ gem install kontena-cli:0.12
```

- to enable Kontena Vault, set `VAULT_KEY` and `VAULT_IV` env variables to master:

```
$ sudo vim /etc/systemd/system/kontena-server-api.service.d/vault.conf
[Service]
Environment=VAULT_KEY="<vault_key>"
Environment=VAULT_IV="<vault_iv>"

$ sudo systemctl daemon-reload
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

`VAULT_KEY` / `VAULT_IV` should be random strings. They can be generated from bash:

```
$ cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1
```

** Custom Installs**
- update master & agent containers to 0.11
- to enable Kontena Vault, set `VAULT_KEY` & `VAULT_IV` env variables to master

### Upgrading from 0.9 to 0.10

- update master & agent containers

### Upgrading from 0.8 to 0.9

- update master & agent containers

### Upgrading from 0.7 to 0.8

#### Ubuntu

**Master Server**

- upgrade package: `sudo apt-get update && sudo apt-get install kontena-server=0.8.0-1`

**Agent (all nodes)**

- remove `--bridge=weave` and `--fixed-cidr="10.81.0.0/16"` from `/etc/default/docker`
- restart docker: `sudo restart docker`
- stop weave: `sudo stop weave-helper && sudo stop weave`
- stop etcd: `sudo stop kontena-etcd`
- upgrade agent: `sudo apt-get update && sudo apt-get install kontena-agent=0.8.0-1`
- restart docker: `sudo restart docker`
- validate that node connects to master (using kontena cli): `kontena node list`
