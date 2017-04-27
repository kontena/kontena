# Changelog

## [1.2.1.rc1](https://github.com/kontena/kontena/releases/tag/v1.2.1.rc1) (2017-04-27)

### Known issues

Known regressions in the new Kontena 1.2.0 release compared to earlier releases.

* Service deploys can get stuck if there are several queued deploys when a service finishes deploying #2212
* Queued deploys time out after 10s if another deploy is running, leaving them stuck #2213
* Stopping service does not abort running deploy #2214

### Fixed issues

* Stack upgrade variable defaulting from master broke in 1.2.0 #2216
* Service volume mounts with :ro breaks validation in 1.2.0 #2219
* CLI: stack reader explodes on an empty stack file: `NoMethodError : undefined method ''[]' for false:FalseClass` #2204
* Missing documentation re upgrading path for named volumes #2222
* OSX cli package (omnibus) is missing readline #2194
* Server: GridServiceHealthMonitorJob can pile up deployments #2208

### Changes

* Fix 1.2.0 release notes to document volume migration upgrades (#2223)

#### Agent
* Do not send un-managed volume infos to master (#2189)

#### Server
* Fix GridService#deploy_pending? to consider all unfinished deploys as pending (#2211)

#### CLI
* SSL: Give hint about setting certs path (#2201)
* Make kontena_cli_spec spec test what it was supposed to (#2210)
* Fix variable value defaulting from master during stack upgrade (#2217)
* Fix validation of volume definitions with permission flags (#2220)
* Handle empty YAML files in stack commands (#2206)
* Add rb-readline to CLI installer (#2205)

## [1.2.0](https://github.com/kontena/kontena/releases/tag/v1.2.0) (2017-04-21)

### Highlights

#### Experimental volumes support
The Kontena 1.2 release introduces [experimental support for volume management](https://kontena.io/docs/using-kontena/volumes).
Stack services can now [use](https://kontena.io/docs/references/kontena-yml#volumes) volumes created by `kontena volume create`, and the service and volume instances will be scheduled together.

Kontena volumes can use volume drivers provided by Docker plugins installed on the host nodes, such as [rexray](https://rexray.codedellemc.com/).

See the [Upgrading](#upgrading-stacks-with-services-using-named-docker-volumes) section for existing stacks with services using named volumes, which were previously deployed as implicitly created local Docker volumes.

The exact details of how these Kontena volumes are managed may still change as the implementation evolves. If you use the experimental Kontena volumes support, be prepared to change your volume definitions as necessary when upgrading to newer Kontena versions.

#### Native IPsec overlay network encryption

Host nodes will be upgraded to Weave 1.9.3, and switch to using the new IPSec [encrypted datapath](https://kontena.io/docs/core-concepts/networking#encrypted-datapath) for the overlay networking between host nodes.

The new encrypted datapath uses native Linux IPsec encryption, providing improved performance compared to the current [userspace `sleeve`](https://kontena.io/docs/core-concepts/networking#sleeve) transport.
Host nodes will fall back to the current UDP-based `sleeve` transport if they are unable to send or receive IPsec ESP packets. Note that the default firewall rules for e.g. Google Cloud Platform deny IPsec ESP packets by default.

#### Improved service deployment and agent communication

The server and agent have been improved to be more robust in the case of various error and overload situations affecting service deployments.
The agent can now recover from various errors, healing itself and resolving any deployment inconsistencies.

The `kontena service deploy` and `kontena stack` commands now provide better reporting of deployment errors.

#### Support for Kontena Cloud metrics and real-time updates

The Kontena 1.2 release supports additional host/container stats used for the updated [Kontena Cloud](https://cloud.kontena.io) dashboard, as well as realtime streaming of updates as services are deployed or host nodes update. Refer to the [release blog post](https://blog.kontena.io/kontena-1-2-0-release/#kontenacloudupdates) for more details.

#### CLI

* [`kontena shell`](https://github.com/kontena/kontena-plugin-shell#kontena-shell)

    The [Kontena Shell](https://github.com/kontena/kontena-plugin-shell#kontena-shell) is available as an optional plugin for Kontena 1.2, offering an improved interactive console interface: `kontena plugin install shell`

* [`kontena grid create --subnet --supernet`](https://kontena.io/docs/using-kontena/grids#grid-subnet-supernet)

    If the default `10.80.0.0/12` internal overlay network address space overlaps with the the private networking address space on the host node provider, you can chose a different internal overlay networking address space for use by the Kontena host nodes and service containers.

* [`kontena grid update --log-forwarder fluentd`](https://kontena.io/docs/using-kontena/grids#logging-options)

    The agent can ship service container logs to an external `fluentd` server.

* `kontena grid events`, `kontena stack events`, `kontena service events`

    Follow scheduling and deployment related-events across the Kontena master and node agents.

* `kontena stack {build,install,upgrade,validate} --values-to --values-from`

    Automate [Kontena stack variables](https://kontena.io/docs/references/kontena-yml-variables) across deployments.

* `kontena stack validate --online`

    Stack validation happens offline by default, avoiding any side-effects such as Kontena Vault writes.

* `kontena stack upgrade --force`

    Require confirmation if upgrading a different stack file.

* `kontena service show`

   List containers by instance.

* `kontena service rm --instance`

   Force a service instance to be rescheduled.

* `kontena node ssh --any`

    SSH to the first available connected node.

* `kontena node rm`

    Refuse to remove a node that is still online.

* `kontena master user`

    Renamed and deprecated `kontena master users`.

* `kontena volume create`, `show`, `remove`, `list`

    See the [Volumes](https://kontena.io/docs/using-kontena/volumes) documentation.

#### Stacks

* Support named `service: volumes: - volume:/path`

    All [named service volumes](https://www.kontena.io/docs/references/kontena-yml.html#named-volume) must now be defined in the new `volumes` section.

* New `volumes` section

    See the new [Stack Volume Configuration Reference](https://www.kontena.io/docs/references/kontena-yml.html#volume-configuration-reference) documentation.

### Upgrading

#### Upgrading stacks with services using named Docker volumes

Kontena Services could also use named volumes prior to Kontena 1.2, which would implicitly create local Docker volumes on each host node that service instances were deployed to.

After upgrading the server to Kontena 1.2, any such named Docker volumes used by existing services will appear in `kontena volume ls`, in the form of [grid-scoped volumes](https://www.kontena.io/docs/using-kontena/volumes.html#scope-grid) using the default `local` driver. However, trying to install or upgrade a existing stack file containing services that use those named volumes will fail with a validation error: `service ... volumes ...: defines volume name, but file does not contain volumes definitions`

The stack files containing services using named Docker volumes must be edited to use to use the new `volumes` section. The migrated Kontena volumes shown in `kontena volume ls` can be referenced as external volumes in the stack:

```yaml
stack: test/test
services:
  test:
    volumes:
      - test:/test
volumes:
  test:
    external:      # equivalent to `external: true`, matching the name of the volumes section
      name: test
```

After editing the stack file, the stack can be upgraded, and the services can continue to be deployed as before. Assuming the services are using affinity filters such that they continue to be deployed to the same host nodes, then any service containers deployed with Kontena 1.2 will use the existing named local Docker volumes that were implicitly created by earlier Kontena deployments. Using affinity filters to schedule onto specific nodes was already necessary for the stable use of named service volumes in earlier versions of Kontena.

### Known issues

Known regressions in the new Kontena 1.2 release compared to earlier releases.

* Kontena 1.2 cadvisor with rshared bind-mounts is broken on distros running Docker in a non-shared mount namespace #2175

    Service container stats will not be available for host nodes installed using distribution packages that configure the Docker service to run in a separate non-shared mount namespace.

* Stack upgrade / Service update will not re-deploy service on removal of embedded objects (#2109)

    Removing hooks, links, secrets or volumes from a stack service will not re-deploy the service containers after a `kontena stack upgrade`. Use `kontena service deploy --force` to update the service container configuration.

### Fixed issues

#### [1.2.0.rc1](https://github.com/kontena/kontena/releases/tag/v1.2.0.rc1) (2017-04-07)

* Inconistent `master_admin` access checks (#1442)
* Enable us to pipe service(/cluster?) logs to ELK Stack for example (#1719)
* Agent websocket client connect errors are too vauge (#1749)
* stack install && upgrade to have --values-to (#1789)
* Constant GridServiceDeployer messages for 'daemon' services (#1862)
* Stack deploy hangs in "Waiting for deployment to start" if the deployed service is in restart loop (#1866)
* ServiceBalancerJob loop on daemon services with affinity filter (#1895)
* can not remove "partially_running" stack (#1928)
* Google OAuth 2.0 needs redirect URI to get an access token (#2015)
* Stack vault resolver shows errors (#2059)
* Secret update triggers update of linked service even value does not change (#2094)

#### [1.2.0.rc2](https://github.com/kontena/kontena/releases/tag/v1.2.0.rc2) (2017-04-13)

* After weave upgrade, service aliases are missing from DNS #2079
* Agent should check that volume driver match before reusing it #2089
* Stack upgrade can remove linked-to services, breaking linking services #1769
* Cli: kontena volume ls cuts long volume names #2083
* Stack deploy and service deploy error states are broken #2127
* Stateful service with daemon strategy behaviour is broken #2133
* Re-creating indexes in migrations may timeout puma worker boot #2120

#### [1.2.0.rc3](https://github.com/kontena/kontena/releases/tag/v1.2.0.rc3) (2017-04-20)

* Agent starts outdated container instead of re-creating it #2154
* Service with newer image is not deployed without force #2171
* CreateEventLog migration throws error if index is building #2164
* Unresolvable statsd endpoint crashes NodeInfoWorker #2165
* rake kontena:reset_admin throws error #2168

#### [1.2.0](https://github.com/kontena/kontena/releases/tag/v1.2.0) (2017-04-21)

* Stack complains about bind mounts #2192
* Agent pulls images and may re-create service containers after reboot/upgrade if Docker image has been updated #2197
* CLI: kontena stack deploy does not report instance deploy errors #2196

### Changes

* Improve how agent rpc server handles requests (#1607)
* more e2e specs (#1830)
* Configurable grid subnet, supernet (#1323)
* Refactor all agent communication to msgpack rpc (#1855)
* Run e2e specs with docker-compose inside docker-compose with CoreOS inside Vagrant (#1878)
* Add timestamps to host node and container stats (#1908)
* Test: Skip compose build, bind-mount /app instead (#1881)
* Remove unnecessary spec_helper requires in tests (#1932)
* Fix ubuntu packages to also support docker-{ce,ee}, fix docker-engine dependencies (#1950)
* Fix travis Ubuntu package deployment to bintray (#1953)
* Fluentd log forwarder (#1860)
* Fix querying of service logs by instance number (#1874)
* Fix Ubuntu xenial package install to not override prompted debconf values with empty values from the default config file (#1975)
* Refactor agent to pull services desired state from the master (#1873)
* Change 2.4.0 to 2.4.1 in travis (#2017)
* Store docker engine plugin information (#2022)
* Volumes api (#1849)
* Metrics API > Services and Containers (#1995)
* Adding CPU to node usage.  Adding more memory stats to metrics API responses.  Adding more unit tests, updating docs. (#2035)
* Volume instance scheduling (#2020)
* Fix nil backtraces in rpc errors (#1998)
* Service instance deploy state, errors (#2034)
* WaitHelper threshold for logging (#2072)
* Grid/stack/service event logs (#2028)
* Volume show command & API (#2099)
* Service instances api & related cli enhancements (#2101)
* Do not log entire yield value from wait_helper (#2124)
* fix e2e service start/stop tests (#2130)
* Improve websocket timeouts and node connection open/close logging (#2142)

#### Docs
* Docs: link env variables reference to summary (#1912)
* Updating development.md guide to include step to delete master nodes from local cli config file (#1909)
* docs: fix upgrading section links (#1941)
* docs (lb) Example on how to include cert intermediates. (#1939)
* Volume related api docs (#2075)
* Docs for volumes (#2049)
* kontena.yml reference improvements (#2179)
* Mention that re-scheduling happens only if service is stateless (#2178)
* docs: service rescheduling after node removal (#2182)

#### Agent
* Agent: Upgrade to faye-websocket 0.10.7 with connection error reasons, close timeouts (#1757)
* Agent: Update weave to 1.9.3 (#1922)
* Fix Agent state_in_sync for stopped containers (#2023)
* Bump IPAM to version 0.2.2 (#2030)
* Refactor agent to use Observable node info (#2011)
* Agent observable fixes (#2042)
* Fix pod manager to populate service name from docker containers (#2064)
* Send both legacy & new driver information from a node (#2061)
* Mount cAdvisor volumes with rshared (#2005)
* Improve agent RPC request error handling (#2008)
* Fix observable spec races (#2106)
* Throttle agent logs streams if queue is full (#2111)
* Fix agent to raise on service container start, stop, restart errors (#2138)
* Check volume driver match when ensuring volume existence (#2135)
* Improve agent resource usage (#2143)
* Reduce agent info logging (#2155)
* Fix agent WeaveWorker to not start until Weave has started (#2153)
* ContainerInfoWorker fixes (#2147)
* Refactor node stats to NodeStatsWorker (#2166)
* Remove unused ContainerStarterWorker (#2181)
* Don't crash ImagePullWorker if pull fails (#2172)
* Fixing nice stats collection typo bug (#2190)
* Check that image is up-to-date in ServicePodWorker (#2177)
* trigger image pull only if deploy_rev changes (#2198)

#### Server
* Display server version on master container startup (#1839)
* Stack deploy command spec was sleeping (#1746)
* Fix master auth config race condition issues (#1921)
* Fixing node_id issue in server node_handler_spec. (#1944)
* Fix grid update specs for --log-forwarder fluentd (#1971)
* Harmonize grid access checks (#1970)
* Fix error in #stop_current_instance if host_node is nil (#2007)
* Save host_node_id in CreateGridServiceInstance migration (#2006)
* Replace server timeout { sleep until ... } loops with non-interrupting wait_until { ... } loops (#1987, #2010)
* Send redirect_uri in authorization_code request as required by some providers (#2016)
* Fix missing server Rpc::GridSerializer fields (#2014)
* Trace and fix server sharing of Moped::Session connections between threads (#1965)
* Send events to Kontena Cloud in real time (#1906)
* don't count volume containers into totals in aggregation (#2031)
* Fix grid metrics CPU calculation (#2044)
* remove duplicate json-serializer from Gemfile (#2055)
* Improve RpcServer performance (#2050)
* Improve server stack mutatations to return errors for multiple services (#1976)
* Remove volume creation as part of stacks (#2070)
* Fix possible thread leaks in WebsocketBackend (#2056)
* Refactor stacks api to always require extenal name for a volume (#2077)
* Add missing DuplicateMigrationVersionError (#2066)
* Do nothing if secret value does not change on update (#2095)
* Only cleanup nodes labeled as ephemeral (#2084)
* Fix service update changes detection (#2097)
* Fix scheduler to raise better error if given empty nodes (#2107)
* Fix migration timeout issues (#2123)
* do not reschedule stateful service automatically (#2137)
* Fix service, stack deploy errors (#2132)
* Server WebsocketBackend EventMachine watchdog (#2139)
* migration service instance also from volume containers (#2129)
* Fix stack deploy service removal (#2128)
* Bring scheduler node offline grace period back (#2141)
* Include CPU in resource usage json (#2151)
* Add service pod caching on Rpc::NodeServicePodHandler (#2146)
* Fix scheduler to notice if instance node was removed (#2152)
* Fix server NodePlugger.plugin logging of new nodes without names (#2156)
* Fix rake tasks to require celluloid/current (#2169)
* Return container stats only from running instances (#2160)
* remove bundler from bin/kontena-console (#2170)
* Fix Service Metrics CPU (#2162)
* Raise puma worker boot timeout & remove background threads (#2187)

#### CLI
* Upgrade to tty-prompt 0.11 with improved windows support (#1901)
* Fix cli specs to use an explicit client instance_double (#1747)
* Modifications to simplify kontena-cli homebrew formula (#1889)
* CLI: Fix stacks YAML reader handling of undefined variables (#1884)
* kontena node ssh --any: connect to first connected node (#1359)
* Speed up CLI launching by lazy-loading subcommands (#1093)
* Fixing paths for nested sub commands in calls to load_subcommand. (#1934)
* Send file:// as registry url to allow backwards compatibility with pre v1.1.2 masters (#1930)
* Require --force or confirmation when upgrading to a different stack (#1940)
* Fix omnibus osx wrapper args passing (#1967)
* Fix CLI to output API errors to STDERR (#1963)
* Upgrade opto to 1.8.4 (#1935)
* Validate hook names in kontena.yml (#2019)
* Add --values-to from stack validate to the rest of the stack subcommands (#1985)
* Stack yaml volume mapping parser and validation support (#1957)
* Validate volumes before stack gets created or updated (#2043)
* Deprecate master users subcommand in favor of master user (#1984)
* CLI exception output normalization (#2057)
* Make stack validate not connect to master unless asked (#2060)
* cli: fix node ssh command API URLs (#2078)
* Invite and invite hook were using the deprecated "master users" (#1984) (#2085)
* require force or confirmation to remove a volume (#2093)
* Refuse to remove an online node (#2086)
* Fix cli master logout module definition (#2104)
* Fix CLI stack logs missing requires, spec (#2103)
* Added prompt to commands that wait for input from STDIN (#2045)
* bump hash-validator to 0.7.1 which fixes the 'external: false' validation (#2105)
* Make stack variable yes/no prompts honor default value (#2053)
* CLI: mark volumes commands as experimental (#2108)
* In cli login command, finish method was returning nil, which caused browser web flow prompt even when a valid token was passed in (#2145)
* Use tty-table for volume ls (#2136)
* Reduce already initialized constant warnings in api client (#2140)
* "kontena complete --subcommand-tree" prints out the full command tree for tests (#2102)
* CLI logo now says "cli" (#2167)
* Warn, don't exit, when a plugin fails to load (#2184)
* Validate volume declaration on cli only if named volumes used (#2193)
* Stack deploy error reporting (#2199)

## [1.1.2](https://github.com/kontena/kontena/releases/tag/v1.1.2) (2017-02-24)

**Master & Agents:**

- Fix stack service link validation errors (#1876)
- Do not start health check if no protocol specified (#1863)
- Do not filter out a node that already has the service instance when replacing a container (#1823)
- Ubuntu xenial packaging dpkg-reconfigure support (#1754)
- Fix stack service reverse-dependency sorting on links when removing (#1887)
- Fix clearing health check attributes on stack upgrade (#1837)
- Registry url was not saved correctly in stack metadata (#1870)

**CLI:**

- Fix stack service_link resolver default when value optional (#1891)
- Update year to 2017 in CLI logo (#1840)
- Avoid leaking CLI auth codes to cloud in referer header (#1896)

**Other:**

- Docs: fix volumes_from examples and syntax (#1872)
- Dev: Docker compose based local e2e test env (#1838)

## [1.1.1](https://github.com/kontena/kontena/releases/tag/v1.1.1) (2017-02-08)

**Master & Agents:**

- Remove volume containers when removing nodes (#1805)
- Document master HA setup (#1721)
- Allow to clear deploy options after stack install (#1698)

**CLI:**

- Fix service link/unlink errors (#1814)
- Fix plugin cleanup and run it only when plugins are upgraded (#1813)
- Exit with error when piping to/from a command that requires --force and it's not set (#1804)
- Simple menus were not enabled on windows by default as intended in 1.1.0 (#1802)
- Fix for stack variable prompt asking the same question multiple times when no value given (#1801)
- Fix stack vault ssl certificate selection and service link prompts not using given default values (#1800)
- Allow "echo: false" in stack string variables for prompting passwords (#1796)
- Fix stack conditionals short syntax for booleans (#1795)
- Invite self and add the created user as master_admin during 'kontena master init-cloud' (#1735)
- Fix the new --debug flag breaking DEBUG=api full body inspection (#1821)

## [1.1.0](https://github.com/kontena/kontena/releases/tag/v1.1.0) (2017-02-03)

**Master & Agents:**

- Initialize container_seconds properly (#1764)
- Fix service volume update (#1742)
- Set puma workers based on available CPU cores (#1683)
- Switch to use Alpine 3.5 (#1621)
- Add container hours telemetry data (#1589)
- Validate that secrets exist during service create and update (#1570)
- Set grid default affinity (#1564)
- Update Weave Net to 1.8.2 (#1562)
- Changed log level of some messages to debug level in agent (#1519)
- Better deployment errors for "Cannot find applicable node for service instance ..." (#1512)
- Fix service container names to drop null- prefix, and use stack.service-N (#1494)
- Say role not found instead of role can not be nil in role add (#1458)
- Added kontena-console command to master for debugging (#903)
- Stop container health check also on kill event (#1699)
- Update image registry to 2.6.0 [enhancement] #1704

**CLI:**

- Remove deprecated commands and options (#1759)
- Stack service link (prompt) resolver (#1756)
- Read variable defaults from master when running stack upgrade (#1662 + #1751)
- Stacks can now be installed/upgraded/validated from files, registry or URLs (#1748 #1736)
- Vault ssl cert resolver for stacks (#1745)
- Improve service stack revision visibility (#1744)
- One step master --remote login (#1739)
- Detect if environment supports running a graphical browser (#1738)
- Deploy stack by default on install/upgrade (#1737)
- Support liquid templating language in stack YAMLs (#1560 #1734)
- Better error message when vault key nil/empty in vault resolver (#1728)
- Add kontena service exec command (#1726)
- Switch cli docker image to use root user (#1717)
- Show origin of installed stack (#1711)
- Improve stack deploy progress output (#1710)
- Make --force more predictable in master rm (#1703)
- Use the master url to build the redirect uri in init-cloud (#1701)
- Rescue from broken pipe (#1684)
- Update spinner message while spinning (#1679)
- Stack service_instances resolver (#1678)
- Show etcd health status (#1677)
- Set master config server.provider during deploy (#1675)
- Optionally use sudo when running docker build/push (#1673)
- Show instance name in service stats (#1669)
- Vault import/export (#1655)
- Master/CLI version difference warning (#1636)
- Add kontena vault import/export commands (#1634)
- Install plugins under $HOME/.kontena/gems and without shell exec (#1628)
- Improve interactive prompts on Windows (#1585)
- Move debug output to STDERR (#1543)
- Add kontena node/grid health commands (#1468)
- Custom instrumentor for debugging http client requests when DEBUG=true (#1436)
- Add kontena --version and global --debug (#1291)
- Enable sending commands to hosts via kontena master/node ssh (#1205)
- OSX CLI installer and automated build (#1112)
- Display agent version in node list (#996)

## [1.0.6](https://github.com/kontena/kontena/releases/tag/v1.0.6) (2017-01-18)

**Master & Agents:**

- agent: fix cAdvisor stats to ignore systemd Docker container mount cgroups (#1657)

## [1.0.5](https://github.com/kontena/kontena/releases/tag/v1.0.5) (2017-01-13)

**Master & Agents:**

- fix loadbalancer link removal (#1623)
- disable cAdvisor disk metrics & give lower cpu priority (#1629)
- return 404 if stack not found (#1613)
- fix EventMachine to abort on exceptions (#1626)

**CLI:**

- fix kontena grid cloud-config network units (#1619)

## [1.0.4](https://github.com/kontena/kontena/releases/tag/v1.0.4) (2017-01-04)

**Master & Agents:**

- Send labels with the initial ws connection headers (#1597)
- Fix WebsocketClient reconnect (#1602)


**CLI:**
- Calm down service status polling interval on service delete (#1596)
- Tell why plugin install failed (#1510)

**Loadbalancer:**

- Allow to set custom SSL ciphers (#1591)
- Add custom LB level settings (#1586)


## [1.0.3](https://github.com/kontena/kontena/releases/tag/v1.0.3)

**Master & Agents:**
- Change default cadvisor image to official ([#1569](https://github.com/kontena/kontena/pull/1569))
- Hide weave password from logs ([#1578](https://github.com/kontena/kontena/pull/1578))

**CLI:**
- Return validation errors properly when extending services ([#1581](https://github.com/kontena/kontena/pull/1581))
- Fix stack build command ([#1577](https://github.com/kontena/kontena/pull/1577))
- Use safe_yaml to load YAML files ([#1573](https://github.com/kontena/kontena/pull/1573))
- Fix instance parsing in service logs ([#1571](https://github.com/kontena/kontena/pull/1571))

## [1.0.2](https://github.com/kontena/kontena/releases/tag/v1.0.2)

**Master & Agents:**

- Fix error in StackDeployWorker when stack service has been removed ([#1544](https://github.com/kontena/kontena/pull/1544))
- Fix registry & vpn stack deploy tracking ([#1537](https://github.com/kontena/kontena/pull/1537))
- Block calls to Weave#start via #on_node_info ([#1545](https://github.com/kontena/kontena/pull/1545))
- Fix agent to avoid DNS lookups for localhost with a missing /etc/hosts ([#1550](https://github.com/kontena/kontena/pull/1550))
- Don't re-deploy dependant services on stack deploy ([#1552](https://github.com/kontena/kontena/pull/1552))
- Fix error when removing orphan service volumes ([#1554](https://github.com/kontena/kontena/pull/1554))

**CLI:**

- Fix VPN create ([#1536](https://github.com/kontena/kontena/pull/1536))
- Add stack commands to tab completer ([#1540](https://github.com/kontena/kontena/pull/1540))
- New Stack file resolvers: interpolate and evaluate ([#1528](https://github.com/kontena/kontena/pull/1528))

## [1.0.1](https://github.com/kontena/kontena/releases/tag/v1.0.1) (2016-12-09)

**Master & Agents:**

- Fix possible race condition in GridServiceScheduler (#1532)
- Fix ServiceBalancer greediness (#1522)
- Fix StackDeploy success state (#1509)
- Boot em&celluloid with initialisers (#1503)
- Fix binding same port on multi IPs (#1490)
- Fix service show DNS (#1487)
- Garbage collect orphan service containers (#1483)
- Deploy stack service one-by-one (#1482)
- Stack-warare loadbalancer (#1481)
- Resolve volumes-from correctly with < 1.0.0 created services (#1455)


**CLI:**

- - Fix service containers command (#1514)
- Use —name when parsing stacks (#1505)
- Fix auth token refreshing (#1479)
- Set GRID and STACK variables for stack files (#1475)



## [1.0.0](https://github.com/kontena/kontena/releases/tag/v1.0.0) (2016-11-29)

**Master & Agents:**

- improve stacks functionality (#864, #1339, #1331, #1338, #1333, #1345, #1347, #1356, #1362, #1358, #1366, #1368, #1372, #1384, #1385, #1386, #1390, #1393, #1378, #1409, #1415, #1425, #1434, #1439)
- improved network / ipam handling (#955, #1274, #1300, #1324, #1322, #1326, #1332, #1336, #1344, #1380, #1379, #1391, #1392, #1398)
- cloud integration (#1340, #1389, #1399, #1408, #1407, #1419)
- rest api docs (#1406)
- refactor secrets api endpoints to match overall naming (#1405)
- refactor containers api endpoint (#1363, #1426)
- refactor nodes api endpoints (#1427, #1441, #1445, #1444, #1447)
- rename services api container_count attribute to instances (#1404)
- fix WaitHelper timeout (#1361)
- do not restart already stopped service instances (#1355)
- make ContainerLogWorker safer (#1350)
- add health status actions on agent and master (#1115)
- enhanced deployment tracking (#1348, #1349)
- fix TelemetryJob version compare (#1346)

**CLI:**

- stack registry integration (#1403, #1428, #1433, #1429)
- fix current master selection after master login (#1381)
- stacks parser (#1351, #1417)
- install self-signed cert locally (#1337, #1416)
- refactor login commands and improve coverage (#1283)
- deprecate service force deploy (#1295)
- option to check only cli version (#1269)
- show docker version in node show (#1255)
- add / Rm multiple node labels. Added label list command. (#1296)
- add quiet option to service list command (#1312)
- remove previous version of a plugin on install (#1313)


## [0.16.3](https://github.com/kontena/kontena/releases/tag/v0.16.3) (2016-11-15)

**Master & Agents:**

- fix environment rake task (#1311)
- watch & notify when dead containers are gone (#1289)
- fix external registry validation (#1310)
- return correct error json when service remove fails (#1302)
- log weaveexec errors (#1286)
- fix all requires to use deterministic ordering across different systems (#1282)

## [0.16.2](https://github.com/kontena/kontena/releases/tag/v0.16.2) (2016-11-03)

**Master & Agents:**

- sort initializers while loading, load symmetric-encryption before seed (#1280, #1277)

**CLI:**

- remove use of to_h for ruby 2.0 compatibility (#1267, #1266)
- fix master list command if current master not set (#1268)

## [0.16.1](https://github.com/kontena/kontena/releases/tag/v0.16.1) (2016-10-31)

**Master & Agents:**

- fix Agent IfaceHelper#interface_ip Errno::EADDRNOTAVAIL case (#1256)
- call attach-router if interface ip does not exist (#1253)
- collect stats only for running containers (#1239)
- fix telemetry id (#1215)
- use upsert in config put (#1221)
- create indexes before running config seed (#1220)

**CLI:**

- login no longer raises when SERVER_NAME is null (#1254)
- fix master provider save to cloud (#1250)
- add script security to openVPN config output (#1231)
- strip possible trailing arguments from remote code display (#1245)
- set cloud master provider and version if provision plugin returns them (#1180)
- don't require current master on first login (#1242)
- better error messages when auth code exchange fails (#1222)
- show username when logging in using auth code (#1236)
- rename duplicate masters during config load (#1238)
- use shellwords to split commands (#1201)
- convert excon timeout variables to integers (#1227)

## [0.16.0](https://github.com/kontena/kontena/releases/tag/v0.16.0) (2016-10-24)

**Master & Agents:**

- OAuth2 support (#1035, #1106, #1108, #1120, #1141)
- optimize service containers api endpoint (#1195)
- don't use force when removing containers (#1196)
- refuse start master if incorrect db version (#1187)
- server telemetry / anon stats (with possibility to opt-out) (#1179)
- improve grid name validation (#1162)
- set default timeout to stop/restart docker calls (#1167)
- restart weave if trusted subnets change (#1147)
- loadbalancer: basic auth support (#1060)
- update Weave Net to 1.7.2 (#1146)
- refactor agent image puller to an actor (#942)
- update etcd to 2.3.7 (#1085)
- add instance number to container env (#1042)
- refactor container_logs api endpoint & fix limit behaviour (#995)

**CLI:**

- OAuth2 support (#1035, #1082, #1094, #1077, #1097, #1096, #1101, #1103, #1105, #1107, #1133, #1129, #1119, #1080, #1139, #1138, #1176, #1183, #1203, #1207, #1210)
- fallback to master account in config parser (#1199)
- increase client read_timeout to 30s (#1198)
- fix vpn remove error (#1185)
- fix plugin uninstall command (#1184)
- kontena register with a link to signup page (#1177)
- known plugin subcommands will now suggest installing plugin if not installed (#1175)
- remove Content-Type request header if request body is empty (#1157)
- show service instance health (#1153)
- improved request error handling (#1155)
- improved tab-completion script (includes zsh support) (#1168)
- fix `kontena grid env` to use correct token (#1137)
- interactive server deletion from config/cloud (#1131)
- replace dry-validation with hash_validator gem (#1041)
- fix docker build helpers to not use shell syntax (#1124)
- add `kontena container logs` command (#1001)
- show grid token only with `--token` option (#1109)
- show error if installed plugin is too old (#1116)
- allow to set grid token manually in `kontena grid create` (#1046)
- new spinner (#1035, #1083, #1181)
- replace colorize gem with pastel (#1035, #1104, #1114, #1117, #1145)
- give user better feedback when commands are executed (#1057)
- do not send Content-Type header with GET requests (#1078)
- show container exit code (#927)
- `app deploy --force` (deprecates `--force-deploy`) (#969)

**Packaging:**

- Ubuntu Xenial (16.04) packages (#1150, #1169, #1171, #1173, #1186, #1189)
- allow to use docker 1.12 in Ubuntu packages (#1169)
- ignore vendor files when building docker images (#1113)

## [0.15.5](https://github.com/kontena/kontena/releases/tag/v0.15.5) (2016-10-02)

**CLI:**

- allow to install plugins in cli docker image (#1055)
- handle malformed YAML files in a sane way (#994)
- do not clip service env output (#1036)
- handle invalid master name gracefully and improve formatting (#997)

## [0.15.4](https://github.com/kontena/kontena/releases/tag/v0.15.4) (2016-09-22)

**CLI:**

- lock dry-gems to exact versions (#1031)

## [0.15.3](https://github.com/kontena/kontena/releases/tag/v0.15.3) (2016-09-20)

**Master & Agents:**

- reconnect event stream always if it stops without error (#1020)
- set service container restart policy to unless-stopped (#1024)

**CLI:**

- lock cli dry-monads version (#1023)

## [0.15.2](https://github.com/kontena/kontena/releases/tag/v0.15.2) (2016-09-10)

**Master & Agents:**

- retry when unknown exception occurs while streaming docker events (#1005)
- fix HostNode#initial_member? error when node_number is nil (#1000)
- fix master boot process race conditions (#999)
- always add etcd dns address (#990)
- catch service remove timeout error and rollback to prev state (#989)
- fix cli log stream buffer mem leak (#972)
- fix server log stream thread leak (#973)
- use host network in cadvisor container (#954)

**CLI:**

- reimplement app logs, with spec tests (#987, #1007)
- allow to use numeric version value in kontena.yml (#993)
- do not silently swallow exceptions in logs commands (#978)
- remove deprecated provisioning commands from tab-complete (#980)
- lock all cli runtime dependencies (#966)
- allow to use strings as value of extends option in kontena.yml (#965)

## [0.15.1](https://github.com/kontena/kontena/releases/tag/v0.15.1) (2016-09-01)

**Master & Agent:**

- update httpclient  to 2.8.2.3 (#941)
- update puma to 3.6.0 (#945)
- fix custom cadvisor image volume mappings (#944)
- log thread backtraces on TTIN signal (#938)
- add user-agent for http healthcheck (#928)
- allow agent to shutdown gracefully on SIGTERM (#937, #952)

**CLI:**

- default to fullchain certificate with options for cert only or chain (#946)
- freeze dry-configurable version (#949)
- fix build arguments normalizing (#921)

## [0.15.0](https://github.com/kontena/kontena/releases/tag/v0.15.0) (2016-08-11)

**Master & Agent:**
- use correct cadvisor tag in cadvisor launcher (#908)
- do not schedule service if there are pending deploys (#904)
- ensure event subscription cleanup after deploy (#895)
- improve service list api performance (#894)
- update to Alpine 3.4 (#855)
- update Weave Net to 1.5.2 (#916, #849)
- cookie load balancer support (session stickyness) (#841)
- restart event handling for weave (#838)
- index GridServiceDeploy#created_at/started_at fields (#834)
- support for Let's Encrypt certificates (#830)
- fix race condition in DNS add (#820)
- initial health check for remote services (#812, #875, #899, #900)
- fix port definitions to include possibility to set bind ip (#798)
- initial stacks api (experimental) (#796, #822, #893)
- support for tagging master and nodes on AWS (#783)

**CLI:**
- expand build context to absolute path (#906)
- handle env_file on YAML file parsing (#901)
- updated_at timestamp to secret listing (#890)
- discard empty lines in env_file (#880)
- fix deploying registry on azure (#863)
- switch coreos to use cgroupfs cgroup driver (#861)
- do not require config file for whoami command when env is set (#858)
- log tailing retry in EOF case (#835)
- update to dry-validation 0.8.0 (#831, #856)
- support for build args in v2 yaml (#813)
- container exec command to handle whitespace and strings (#803)
- show "not found any build options" only in app build command (#801)
- cli plugins (#794, #917)

## [0.14.7](https://github.com/kontena/kontena/releases/tag/v0.14.7) (2016-08-08)

**Master & Agent:**
- update cadvisor to 0.23.2 (#883)
- fix possible event stream lockups (#878)

## [0.14.6](https://github.com/kontena/kontena/releases/tag/v0.14.6) (2016-07-21)

**Master & Agent:**
- fix agent not reconnecting to master (#859)
- do not reschedule service if its already in queue (#853)
- fix docker event stream filter params (#850)

**CLI:**
- fix deploy interval handling in app yaml parsing (#821)

## [0.14.5](https://github.com/kontena/kontena/releases/tag/v0.14.5) (2016-07-09)

**Master & Agent:**

- stream only container events (#846)
- always touch last_seen_at on pong (#845)
- replug agent on successfull ping (#842)
- fix etcd upstream removal (#836)

**CLI:**

- do not require Master connection on user verification (#839)

## [0.14.4](https://github.com/kontena/kontena/releases/tag/v0.14.4) (2016-07-01)

**CLI:**

- add hard dependency to dry-types gem (#826, #824)

**Other:**

- remove image before tagging, because --force is deprecated (#833)

## [0.14.3](https://github.com/kontena/kontena/releases/tag/v0.14.3) (2016-06-16)

**Master & Agent:**
- update excon to 0.49.0 (#806)
- enable eventmachine epoll (#804)

**CLI:**
- fix aws public ip assign (#808)

## [0.14.2](https://github.com/kontena/kontena/releases/tag/v0.14.2) (2016-06-06)

**Master & Agent:**
- do not allow ImageCleanupWorker to remove agent images (#791)

**CLI:**
- add s3-v4auth flag for registry create (#789)
- improve vpn creation for non-public environments (#787)
- generate yaml v2 formatted files on app init command (#785)

## [0.14.1](https://github.com/kontena/kontena/releases/tag/v0.14.1) (2016-06-03)

**Master & Agent:**
- fix automatic scale down on too many service instances (#772)
- fix nil on cpu usage and refactor stats worker (#769)

**CLI:**
- allow to use app name defined in yaml on app config command (#779)
- fix kontena app build command error (#777)
- enable security group setting for master and nodes in AWS (#775)
- verify Upcloud API access (#774)
- provider labels for AWS, Azure and DO nodes (#773)
- add option in AWS to associate public ip for VPC (#771)
- fix log_opts disappearing after service update (#770)

## [0.14.0](https://github.com/kontena/kontena/releases/tag/v0.14.0) (2016-05-31)

**Master & Agent:**
- dynamic etcd cluster member replacement functionality (#719)
- take availability zones into account in ha scheduling strategy (#754)
- notify grid nodes when node information is updated in master (#752)
- allow to set agent public/private ip via env (#697)
- add rollbar support to master (#475)

**CLI:**
- support for Docker Compose YAML V2 format (#739)
- upcloud.com provisioning support (#748)
- packet.net provisioning support (#726)
- improve azure provisioning (#763)
- confirm dialog on destructive commands (#712)
- allow to define app name in kontena.yml (#751)
- new sub-command `app config` (#749)
- show agent version in node details (#736)
- use region as az in DigitalOcean (#734)
- show initial node membership info (#733)
- option for upserting secrets (#711)
- improved kontena.yml parsing (#696)

## [0.13.4](https://github.com/kontena/kontena/releases/tag/v0.13.4) (2016-05-29)

**Master & Agent:**
- allow to deploy service that is already in deploying state (#743)

**Packaging:**
- add resolvconf as dependency in ubuntu kontena-agent (#744)

## [0.13.3](https://github.com/kontena/kontena/releases/tag/v0.13.3) (2016-05-27)

**Master & Agent:**
- fix possible agent websocket ping_timer race condition (#731)
- fix upstream removal to remove only right container instance (#727)
- fix service balancer not picking up instances without any deploys (#725)
- fix stopped services with open deploys blocking deploy queue (#724)

## [0.13.2](https://github.com/kontena/kontena/releases/tag/v0.13.2) (2016-05-24)

**Master & Agent**
- fix how daemon service state is calculated (#716)
- fix error in HostNode#region when labels is nil (#714)
- fix daemon scheduler node sorting (#708)
- fix how service instance running count is checked (#707)
- take region into account when resolving peer ip's (#706)

**CLI**
- fix service name displaying on app deploy (#717)
- fix confusing user invite text (#715)
- show debug help only for non Kontena StandardErrors (#710)


## [0.13.1](https://github.com/kontena/kontena/releases/tag/v0.13.1) (2016-05-19)

- fix agent websocket hang on close when connection is unstable (#698)

## [0.13.0](https://github.com/kontena/kontena/releases/tag/v0.13.0) (2016-05-18)

**Master & Agent**
- grid trusted subnets (weave fast data path) (#644)
- scheduler memory filter (#606)
- new deploy option: interval (#657)
- cadvisor 0.23.0 (#668)
- add support for `KONTENA_LB_KEEP_VIRTUAL_PATH` (#687)
- improve deploy queue performance (#690)
- schedule deploy for related services on vault secret update (#661)
- do not overwrite service env variables if value is empty (#620)
- return 404 error when (un)assigning nonexisting user to a grid (#665)
- remove container_logs full-text indexing (#677)
- strip secrets from container env variables (#679)
- schedule deploy if service instance has missing overlay_cidr (#685)
- remove invalid signal trap (#689)

**CLI**
- pre-build hooks (#588)
- unify cli subcommands (#648)
- improved memory parsing (#681)
- add `--mongodb-uri` option to aws master create command (#676)
- add `--mongodb-uri` option to digitalocean master create command (#675)
- generate self-signed cert for digitalocean master if no cert is provided (#672)
- point user account requests directly to auth provider (#671)
- fix linked service deletion on `app rm` command (#653)
- fix memory parsing errors (#647)
- sort node list by node number (#646)
- sort service list by updated at (#645)
- remove digitalocean floating ip workaround (#643)
- sort vault secrets & envs by name (#641)
- enable digitalocean & azure master update strategy (#640)
- disable vagrant node update stragegy (#639)
- load aws coreos amis dynamically from json feed (#638)
- tell how to get the full exception when an error occurs (#635)
- merge secrets when extending services (#621)
- new command `master current` (#613)
- show node stats on node details (#607)
- save login email to local config (#589)

## [0.12.3](https://github.com/kontena/kontena/releases/tag/v0.12.3) (2016-05-06)

- fix node unplugger unclean shutdown (#662)

## [0.12.2](https://github.com/kontena/kontena/releases/tag/v0.12.2) (2016-04-26)

- fix too aggressive overlay cidr cleanup (#626)
- fix image puller cache invalidation on new deploy using same image tag (#627)
- do not ignore containers with name containing weave (#631)
- return nil for current_grid if master settings not present in cli (#632)

## [0.12.1](https://github.com/kontena/kontena/releases/tag/v0.12.1) (2016-04-19)

- use overlay ip when checking port status on deploy
- allow to use docker 1.10.x on ubuntu
- allow master_admin role to see all grids
- add missing `master users rm` command
- switch aws provisioning commands to use official aws-sdk
- fix authorize on grid actions
- fix node memory calculation (take buffers & caches into account)
- fix `vault list` command output width cropping
- fix typo in `grid list` command when no grids exist
- fix `service containers` exception on nil overlay_cidr

## [0.12.0](https://github.com/kontena/kontena/releases/tag/v0.12.0) (2016-04-04)

- improve user roles implementation
- automatic image gc for nodes
- initial statsd metrics implementation
- docker 1.10 support
- weave 1.4.5
- cadvisor 0.22.0
- etcd 2.2.4
- move cadvisor to host namespace
- refactor agent workers to actors
- improve node/host level metrics
- improve output of `node list` sub-command
- improve output of `service list` sub-command
- improve output of `logs` sub-commands
- new grid sub-command `grid cloud-config`
- new node sub-commands `service add/remove-label`
- new service sub-commands `service add/remove-secret`
- new service sub-commands `service link/unlink`
- add possibility to override current grid with `--grid` option
- support for DigitalOcean floating ip's
- more consistent `--tail` cli option
- more consistent remove subcommands
- make default log/stats collection size smaller
- retry weave, etcd and cadvisor start on docker exception
- raise error if extended service is missing in base yaml file
- update mongodb driver (moped) to latest stable version
- fix: add wait after removing app services that are linked to other services
- fix: verify agent ws connections periodically
- fix: node name randomness
- fix: do not set hostname if host network mode
- fix: daemon strategy instance count with affinity
- fix: DigitalOcean node termination
- fix: AWS node termination not using correct tag
- remove: deprecated top-level deploy command

## [0.11.7](https://github.com/kontena/kontena/releases/tag/v0.11.7) (2016-03-07)

- increase deploy timeout to 5 minutes
- update docker-api
- make default logs/stats collections smaller

## [0.11.6](https://github.com/kontena/kontena/releases/tag/v0.11.6) (2016-02-13)

- do not update container.deleted_at timestamp if it's already set
- fix error in docker 1.9 when net=host
- fix race conditions in lb cleanup procedure
- allow registry/image name with custom port in kontena.yml
- show missing memory & memory_swap in service details
- fix error in service restart command

## [0.11.5](https://github.com/kontena/kontena/releases/tag/v0.11.5) (2016-02-08)

- handle force_deploy flag correctly on app deploy command

## [0.11.4](https://github.com/kontena/kontena/releases/tag/v0.11.4) (2016-02-08)

- add missing vault update command
- add missing app restart command
- add missing --force-deploy option to deploy commands
- fix broken pid option in kontena.yml

## [0.11.3](https://github.com/kontena/kontena/releases/tag/v0.11.3) (2016-02-01)

- fix error on grid destroy
- fix agent stats collect interval

## [0.11.2](https://github.com/kontena/kontena/releases/tag/v0.11.2) (2016-01-25)

- better error handling on lb changes
- update node information when agent reconnects
- aws provisioner update
- grid env subcommand fix

## [0.11.1](https://github.com/kontena/kontena/releases/tag/v0.11.1) (2016-01-16)

- cleanup etcd correctly when load balanced service is removed
- fix MessageHandler internal caching
- send correct json on auth failure
- do not mark volumes for deletion on unplug event
- search alternate Dockerfile from build context
- do not throttle container log streaming
- update weave to 1.4.2
- send container information to master asap (don't wait for weave to start)
- fix "bring your own load balancer" functionality

## [0.11.0](https://github.com/kontena/kontena/releases/tag/v0.11.0) (2016-01-10)

- secrets management (vault)
- multi master management in cli
- heroku support
- new overlay cidr allocator
- fix memory leak in pubsub
- agent message handler performance improvements
- improve rpc client performance
- improve agent cpu & mem usage
- optimize service start/stop mutations
- show vpn & registry services in service list
- add short rm for remove subcommands
- reject grid remove if grid has nodes
- halt deploy if deployer notices timeout
- use PidMode=host with cadvisor
- refactor lb configuration logic from master to agents
- change service state to deploy_pending when rebalancing or manual deploy is triggered
- switch to puma cluster mode & allow to define puma workers/threads via env variables
- try to acquire distributed lock only once if timeout is zero
- pass `external-registry add` values as options
- rewrite container `/etc/hosts` file with weave
- new parameter `grid env [NAME]` to specify grid, defaults to current grid
- new option `grid current --name` to show only current grid name
- new option `node list --all` to show nodes from all grids
- fix `app logs` error when some of the defined services does not exist in master
- tab complete `master use` names
- raise inotify max user instances in node cloudinit.yml
- require ruby 2.0 or later in kontena-cli
- update weave to 1.4.1
- update docker-api to latest version
- update puma & rack to latest version
- update msgpack to latest version
- update faye-websocket to latest version
- update activesupport to latest patch version
- update kontena master tagline

## [0.10.3](https://github.com/kontena/kontena/releases/tag/v0.10.3) (2016-01-05)

- fix `app scale` command
- cleanup weaveexec volumes

## [0.10.2](https://github.com/kontena/kontena/releases/tag/v0.10.2) (2015-12-14)

- fix shell spinner error on vpn & registry commands
- revert state to running if deploy is cancelled

## [0.10.1](https://github.com/kontena/kontena/releases/tag/v0.10.1) (2015-12-03)

- update container node mapping always when updating container info
- fix agent version update message sending
- use docker hub registry v2 as a default when adding external registry
- use debug log level for rpc notifications in agent

## [0.10.0](https://github.com/kontena/kontena/releases/tag/v0.10.0) (2015-12-01)

- improved scheduler with auto-failover/rebalance
- new deploy strategy: daemon
- new deploy option: min_health
- post-start hooks (commands) for service
- multi-master leader election
- docker 1.9 compatibility
- etcd upgrade to 2.2
- cadvisor upgrade to 0.19
- optimized cadvisor resource usage
- cadvisor port changed to 8989
- improved agent connection logic to master
- initial db migration issue fix
- enable roda render cache
- new `pid` option for service
- possibility to add custom pem file for cli (for each kontena master)
- new commands: `app monitor` & `service monitor <service>`
- new command: `app scale`
- new command: `app show <service>`
- new commands: `service add-env <service>` & `service remove-env <service>`
- new command: `node ssh <service>`
- show reason for service instance error (from docker) in service details
- handle partial log streams better in cli

## [0.9.3](https://github.com/kontena/kontena/releases/tag/v0.9.3) (2015-11-03)

- do not overwrite existing node labels on update
- fix node label affinity when labels do not exist
- append node number to node name if name is not unique within grid
- fix user provided ip on vpn create

## [0.9.2](https://github.com/kontena/kontena/releases/tag/v0.9.2) (2015-10-31)

- export port for web process on app init command
- increase timeout on container create
- fix dockerfile resolving when build points to non-default location
- remove duplicate app subcommand
- do not generate maintainer to dockerfile on app init
- fix error in app init when app.json is not present
- change docker bridge to non-default value on provisioners
- fix `kontena master vagrant start` command (credits: [virtualstaticvoid](https://github.com/virtualstaticvoid))
- fix vpn/dns config in linux workstations
- use nodes internal ip for vpn in vagrant

## [0.9.1](https://github.com/kontena/kontena/releases/tag/v0.9.1) (2015-10-25)

- app init: fix addon services persistence
- update weave to 1.1.2
- fix race condition in container volume creation
- fix internal error when user tried to create service with duplicate name
- fix linked services environment variable build order
- add missing --ssl-cert option to AWS master provisioner

## [0.9.0](https://github.com/kontena/kontena/releases/tag/v0.9.0) (2015-10-12)

- Heroku style deployment model (optional)
- integrated loadbalancing based on haproxy/confd
- AWS master/node provision
- Azure master/node provision
- DigitalOcean master provision
- Vagrant master provision
- etcd helper commands
- multi-master improvements
- grid wide container logs
- Weave 1.1.1
- cAdvisor 0.18.0
- service affinity
- support for env dictionaries in kontena.yml
- support for service network mode option
- support for service log options
- support for picking cli credentials from env variables
- support for auto-updating nodes (node/agent version follows master)
- service add-env/remove-env cli commands
- container inspect cli command
- allow to update service links
- improved db indexing/migration logic

## [0.8.4](https://github.com/kontena/kontena/releases/tag/v0.8.4) (2015-09-21)

- handle agent connection errors on boot
- allow to define weave image names through env variables
- fix reset-password subcommand
- fix duplication on app deploy command

## [0.8.3](https://github.com/kontena/kontena/releases/tag/v0.8.3) (2015-09-18)

- fix db automatic indexing
- add "latest" image tag if it's not specified

## [0.8.2](https://github.com/kontena/kontena/releases/tag/v0.8.2) (2015-09-09)

- update weave to 1.1.0
- add dns entry for etcd
- `kontena registry create` cloud provider fixes
- use host networking in cadvisor
- service network stats fix
- fix multivalue handling in `kontena service deploy` command

## [0.8.1](https://github.com/kontena/kontena/releases/tag/v0.8.1) (2015-09-01)

- fix digitalocean node provision dns issue
- fix failed nodes not detected under some circumstances
- fix deploy -p with empty string
- fix error in container exec command
- fix error in setting node labels
- fix service name validation (do not allow dash as a first char)

## [0.8.0](https://github.com/kontena/kontena/releases/tag/v0.8.0) (2015-08-30)

- initial multi-master support
- simpler setup: can be installed with plain docker commands
- coreos support
- vagrant coreos node provisioning
- digitalocean coreos node provisioning
- latest weave
- revamp overlay networking (separate weave bridge)
- kontena app commands (docker-compose/paas like helpers)
- switch to use weavedns
- refactored cli (better ux / performance)
- static etcd bootstrap (discovery is not needed)
- roda 2.5 upgrade
- registry 2.1 with optional authentication
- minor bug fixes

## [0.7.4](https://github.com/kontena/kontena/releases/tag/v0.7.4) (2015-08-15)

- Fix etcd boot errors on flaky networks

## [0.7.3](https://github.com/kontena/kontena/releases/tag/v0.7.3) (2015-07-26)

- Fix `kontena deploy` regression
- Fix cli service id handling

## [0.7.2](https://github.com/kontena/kontena/releases/tag/v0.7.2) (2015-07-25)

- Fix installation error when eth1 is not present on agent node
- Change default initial grid size to 1

## [0.7.1](https://github.com/kontena/kontena/releases/tag/v0.7.1) (2015-07-24)

- Ubuntu packages docker dependency fix
- Database indexing fix
- Containers api fix

## [0.7.0](https://github.com/kontena/kontena/releases/tag/v0.7.0) (2015-07-22)

- Private Docker registry inside grid
- Improved node join/discovery procedure
- Improved grid availability; grid nodes can resist connection problems to master
- Each grid now has own etcd cluster (only visible to internal network)
- Refactor login/register flows in cli
- Weave 1.0
- Enable Weave encryption
- cAdvisor 0.16
- Docker 1.7 support
- Cli bash autocompletion
- Add possibility to target selected services in `kontena deploy`
- Add prefix wildcard support to kontena.yml files
- Hide internal kontena services from `kontena services list`
- Auto-expire container stats/logs in master

## [0.6.1](https://github.com/kontena/kontena/releases/tag/v0.6.1) (2015-06-01)

- Improve `kontena container exec`
- Fix unexpected behaviour in agent container exec calls
- Fix weave-helper to catch already running containers

## [0.6.0](https://github.com/kontena/kontena/releases/tag/v0.6.0) (2015-05-25)

- New cli command: `kontena deploy`
- New cli commands for managing OpenVPN server
- Weave network configuration improvements
- Server & Agent images are now based on Alpine Linux
- Allow user to register even without access to server
- Resolve public ip of grid node
- Improved high-availability scheduling strategy
- Automatic lost node cleanup routine
- Show container id (with color) in service logs

## [0.5.0](https://github.com/kontena/kontena/releases/tag/v0.5.0) (2015-05-02)

- Fix memory leak problems with Docker streaming API's
- Improve kontena-agent dns performance
- Remove sidekiq from kontena-server (smaller memory footprint)
- Add support for cap_add/cap_drop option for containers
- Improve WebSocket handshake logic with kontena-agent
- Support for binding mounted volumes
- New deploy option: strategy
- New deploy option: wait_for_port
- Update Weave to version 0.10.0
- Update cAdvisor to version 0.12.0


## 0.4.0

- Initial release
