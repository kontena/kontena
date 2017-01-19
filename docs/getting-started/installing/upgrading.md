---
title: Upgrading
---

# Upgrading Kontena from Previous Versions

Upgrading Kontena is easy. In most cases, it is sufficient to update just the Kontena Master
and the Nodes will be automatically updated. CLI updates
can be installed via Rubygems.

## Versions

* [0.15 to 0.16 (latest)](upgrading.md#upgrading-from-0-15-to-0-16)
* [0.14 to 0.15](upgrading.md#upgrading-from-0-14-to-0-15)
* [0.13 to 0.14](upgrading.md#upgrading-from-0-13-to-0-14)
* [0.12 to 0.13](upgrading.md#upgrading-from-0-12-to-0-13)
* [0.11 to 0.12](upgrading.md#upgrading-from-0-11-to-0-12)
* [0.10 to 0.11](upgrading.md#upgrading-from-0-10-to-0-11)
* [0.9 to 0.10](upgrading.md#upgrading-from-0-9-to-0-10)
* [0.8 to 0.9](upgrading.md#upgrading-from-0-8-to-9)

### Upgrading from 0.15 to 0.16

** Official Installation Method**

- restart Master:

```
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

- update CLI:

```
$ gem install kontena-cli
```

** Custom Installs**
- update Kontena Master, Kontena Agent and Kontena CLI Tool to 0.16

** Migration steps **

Starting with the Kontena 0.16 release, Kontena Master uses OAuth2-based authentication. When migrating to this release the new OAuth2 setting must be created for the Master. This can be done with the following steps after the Master is updated:
- update CLI to 0.16
- log in to Kontena Cloud by issuing `kontena cloud login`
  - For this you need an account in [Kontena Cloud](https://cloud.kontena.io)
  - Use the same email address that you have been using previously with Kontena to allow a smooth transition to new OAuth2-based authentication.
- Run `kontena master init-cloud`. This will automatically configure your Kontena Master to use new OAuth2 mechanism.
  > After this:
  > * Users will not be able to reauthenticate without authorizing the
  > Master to access their Kontena Cloud user information
  > * Users that have registered a different email address on Kontena
  > Cloud than the one they currently have as their username in the
  > Master will not be able to authenticate until an administrator
  > of the Kontena Master creates an invitation code for them.

- If you or other users are using a different email address than the one you used previously, you have to invite the new address to use the Master:
  `kontena master users invite john.doe@example.com`


### Upgrading from 0.14 to 0.15

** Official Installation Method**

- restart Master:

```
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

- update CLI:

```
$ gem install kontena-cli
```

** Custom Installs**
- update Kontena Master, Kontena Agent and Kontena CLI Tool to 0.15

### Upgrading from 0.13 to 0.14

** Official Installation Method**

- restart Master:

```
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

- update CLI:

```
$ gem install kontena-cli
```

** Custom Installs**
- update Kontena Master, Kontena Agent and Kontena CLI Tool to 0.14


### Upgrading from 0.12 to 0.13

** Official Installation Method**

- restart Master:

```
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

- update CLI:

```
$ gem install kontena-cli
```

** Custom Installs**
- update Kontena Master, Kontena Agent and Kontena CLI Tool to 0.13

### Upgrading from 0.11 to 0.12

** Official Installation Method**

- restart Master:

```
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

- update CLI:

```
$ gem install kontena-cli:0.12
```

** Custom Installs**
- update Kontena Master, Kontena Agent and Kontena CLI Tool to 0.12

### Upgrading from 0.10 to 0.11

** Official Installation Method**

- restart Master:

```
$ sudo systemctl restart kontena-server-api
$ sudo systemctl restart kontena-server-haproxy
```

- update CLI:

```
$ gem install kontena-cli:0.12
```

- to enable Kontena Vault, set `VAULT_KEY` and `VAULT_IV` env variables to Master:

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
- update Kontena Master and Kontena Agent containers to 0.11
- to enable Kontena Vault, set `VAULT_KEY` & `VAULT_IV` env variables to Master

### Upgrading from 0.9 to 0.10

- update Kontena Master and Kontena Agent containers

### Upgrading from 0.8 to 0.9

- update Kontena Master and Kontena Agent containers

### Upgrading from 0.7 to 0.8

#### Ubuntu

**Kontena Master Server**

- upgrade package: `sudo apt-get update && sudo apt-get install kontena-server=0.8.0-1`

**Kontena Agent (all nodes)**

- remove `--bridge=weave` and `--fixed-cidr="10.81.0.0/16"` from `/etc/default/docker`
- restart docker: `sudo restart docker`
- stop weave: `sudo stop weave-helper && sudo stop weave`
- stop etcd: `sudo stop kontena-etcd`
- upgrade agent: `sudo apt-get update && sudo apt-get install kontena-agent=0.8.0-1`
- restart docker: `sudo restart docker`
- validate that node connects to Kontena Master (using kontena cli): `kontena node list`
