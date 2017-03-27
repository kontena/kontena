---
title: Troubleshooting
---

# Services don't start

## Symptoms

1. `kontena node ls` show nodes in a __OK__ status, but services are not starting.
2. `kontena grid logs` show execeptions that looks like the one below


```
 2017-03-14T00:42:58.000Z kontena-agent: E, [2017-03-14T00:42:58.513088 #1] ERROR -- Kontena::NetworkAdapters::IpamCleaner: Excon::Error::Socket: Connection refused - connect(2) for 127.0.0.1:2275 (Errno::ECONNREFUSED)
 2017-03-14T00:45:30.000Z weave: INFO: 2017/03/14 00:45:30.316532 Expired MAC 36:13:aa:e0:2b:6b at 36:13:aa:e0:2b:6b(knode2)
 2017-03-14T00:45:31.000Z kontena-agent: E, [2017-03-14T00:45:31.312629 #1] ERROR -- Kontena::NetworkAdapters::IpamCleaner: Excon::Error::Socket: Connection refused - connect(2) for 127.0.0.1:2275 (Errno::ECONNREFUSED)
 2017-03-14T00:45:57.000Z weave: INFO: 2017/03/14 00:45:57.237450 Expired MAC 96:68:c9:40:07:ac at 96:68:c9:40:07:ac(knode1)
 2017-03-14T00:45:58.000Z kontena-agent: E, [2017-03-14T00:45:58.513911 #1] ERROR -- Kontena::NetworkAdapters::IpamCleaner: Excon::Error::Socket: Connection refused - connect(2) for 127.0.0.1:2275 (Errno::ECONNREFUSED)
 2017-03-14T00:47:49.000Z kontena-agent: I, [2017-03-14T00:47:49.489335 #1]  INFO -- Kontena::Workers::ImagePullWorker: pulled image: nginx:latest
 2017-03-14T00:48:18.000Z kontena-ipam-plugin: Errno::ECONNREFUSED: Failed to open TCP connection to 127.0.0.1:2379 (Connection refused - connect(2) for "127.0.0.1" port 2379)
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/2.3.0/net/http.rb:882:in `rescue in block in connect'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/2.3.0/net/http.rb:879:in `block in connect'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/2.3.0/timeout.rb:91:in `block in timeout'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/2.3.0/timeout.rb:101:in `timeout'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/2.3.0/net/http.rb:878:in `connect'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/2.3.0/net/http.rb:863:in `do_start'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/2.3.0/net/http.rb:852:in `start'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/2.3.0/net/http.rb:1398:in `request'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/gems/2.3.0/gems/etcd-0.3.0/lib/etcd/client.rb:111:in `api_execute'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /app/app/etcd_client.rb:27:in `version'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /app/app/etcd_client.rb:22:in `initialize'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /app/config.ru:11:in `new'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /app/config.ru:11:in `block in <main'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/gems/2.3.0/gems/rack-1.6.4/lib/rack/builder.rb:55:in `instance_eval'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/gems/2.3.0/gems/rack-1.6.4/lib/rack/builder.rb:55:in `initialize'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /app/config.ru:1:in `new'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /app/config.ru:1:in `<main'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/gems/2.3.0/gems/thin-1.7.0/lib/rack/adapter/loader.rb:33:in `eval'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/gems/2.3.0/gems/thin-1.7.0/lib/rack/adapter/loader.rb:33:in `load'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/gems/2.3.0/gems/thin-1.7.0/lib/rack/adapter/loader.rb:42:in `for'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/gems/2.3.0/gems/thin-1.7.0/lib/thin/controllers/controller.rb:170:in `load_adapter'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/gems/2.3.0/gems/thin-1.7.0/lib/thin/controllers/controller.rb:74:in `start'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/gems/2.3.0/gems/thin-1.7.0/lib/thin/runner.rb:200:in `run_command'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/gems/2.3.0/gems/thin-1.7.0/lib/thin/runner.rb:156:in `run!'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/lib/ruby/gems/2.3.0/gems/thin-1.7.0/bin/thin:6:in `<top (required)'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/bin/thin:23:in `load'
 2017-03-14T00:48:18.000Z kontena-ipam-plugin:   /usr/bin/thin:23:in `<top (required)'
```


## Possible causes

### Kontena agent peer interface is incorrect

Kontena nodes comunicates via a configured peer network which defaults to __eth1__ and fallback to __eth0__. 

If your distribution or environment is using a different interface name, communication in overlay network is compromised.

**Solution:** 

Edit the file __/etc/kontena-agent.env__ and add `KONTENA_PEER_INTERFACE` variable to the correct interface. Repeat the same for __/etc/kontena-server.env__ file in the master nodes.

Example:

```
KONTENA_PEER_INTERFACE=ens33
```

### Cloned docker services have the same docker id

Kontena uses the docker id to identify nodes, if that is the case, things fail in un-expected ways. Also there are some components with some state stored in the server.

You can check the docker id with the comand: `docker info | grep ID:`

**Solution:**

1. You could clone your server **before** installing docker and kontena.
2. You could fix docker ID by removing the file _/etc/docker/key.json_ or _~/docker/key.json_ and restarting docker. 


# OpenVPN Client Don't connect

## Symptoms

1. `kontena vpn create` - executes correctly
2. You create a _.ovpn_ file with `kontena vpn config > vpn.ovpn`
3. Connection to client with your tooling is not working
4. `kontena service logs vpn/server` shows the follow log entries:

```
Sun Mar 19 20:38:58 2017 TLS Error: incoming packet authentication failed from [AF_INET]192.168.183.1:33575
Sun Mar 19 20:39:13 2017 Authenticate/Decrypt packet error: packet HMAC authentication failed
Sun Mar 19 20:39:13 2017 TLS Error: incoming packet authentication failed from [AF_INET]192.168.183.1:33575
```

**Solution:**

1. Try use openvpn client command on the client machine `openvpn --config vpn.ovpn`, if the error: _Options error: Unrecognized option or missing or extra parameter(s) in vpn.ovpn:20: script-security (2.4.0)_ occour, then:

a) Edit the generated _vpn.ovpn_ file and adjust the line _script-security 2system_ remove _system_. The line should be as follow:

```
script-security 2
```

Note: If you don't have the _update-resolv-conf_ scripts, internal grid name resolution will not work automatically. Check the topic bellow.

# OpenVPN connection don't resolv internal grid names

## Symptoms

1. Cluster dns names like _registry.default.kontena.local_ are not resolved by DNS, after a successful VPN connection.

**Solution:**

This issue is distro specific, but the ovpn configuration uses __/etc/openvpn/update-resolv-conf__ script to update local DNS server to point to grid DNS.

**Arch Linux** - You can install the aur package [openvpn-update-resolv-conf](https://aur.archlinux.org/packages/openvpn-update-resolv-conf), and the package _resolvconf_. Note: the aur package has some bugs, follow the comments in the aur page. More complete documentation in https://wiki.archlinux.org/index.php/OpenVPN