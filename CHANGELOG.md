# Changelog

## 0.12.0 (2016-04-04)

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

## 0.11.7 (2016-03-07)

- increase deploy timeout to 5 minutes
- update docker-api
- make default logs/stats collections smaller

## 0.11.6 (2016-02-13)

- do not update container.deleted_at timestamp if it's already set
- fix error in docker 1.9 when net=host
- fix race conditions in lb cleanup procedure
- allow registry/image name with custom port in kontena.yml
- show missing memory & memory_swap in service details
- fix error in service restart command

## 0.11.5 (2016-02-08)

- handle force_deploy flag correctly on app deploy command

## 0.11.4 (2016-02-08)

- add missing vault update command
- add missing app restart command
- add missing --force-deploy option to deploy commands
- fix broken pid option in kontena.yml

## 0.11.3 (2016-02-01)

- fix error on grid destroy
- fix agent stats collect interval

## 0.11.2 (2016-01-25)

- better error handling on lb changes
- update node information when agent reconnects
- aws provisioner update
- grid env subcommand fix

## 0.11.1 (2016-01-16)

- cleanup etcd correctly when load balanced service is removed
- fix MessageHandler internal caching
- send correct json on auth failure
- do not mark volumes for deletion on unplug event
- search alternate Dockerfile from build context
- do not throttle container log streaming
- update weave to 1.4.2
- send container information to master asap (don't wait for weave to start)
- fix "bring your own load balancer" functionality

## 0.11.0 (2016-01-10)

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

## 0.10.3 (2016-01-05)

- fix `app scale` command
- cleanup weaveexec volumes

## 0.10.2 (2015-12-14)

- fix shell spinner error on vpn & registry commands
- revert state to running if deploy is cancelled

## 0.10.1 (2015-12-03)

- update container node mapping always when updating container info
- fix agent version update message sending
- use docker hub registry v2 as a default when adding external registry
- use debug log level for rpc notifications in agent

## 0.10.0 (2015-12-01)

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

## 0.9.3 (2015-11-03)

- do not overwrite existing node labels on update
- fix node label affinity when labels do not exist
- append node number to node name if name is not unique within grid
- fix user provided ip on vpn create

## 0.9.2 (2015-10-31)

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

## 0.9.1 (2015-10-25)

- app init: fix addon services persistence
- update weave to 1.1.2
- fix race condition in container volume creation
- fix internal error when user tried to create service with duplicate name
- fix linked services environment variable build order
- add missing --ssl-cert option to AWS master provisioner

## 0.9.0 (2015-10-12)

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

## 0.8.4 (2015-09-21)

- handle agent connection errors on boot
- allow to define weave image names through env variables
- fix reset-password subcommand
- fix duplication on app deploy command

## 0.8.3 (2015-09-18)

- fix db automatic indexing
- add "latest" image tag if it's not specified

## 0.8.2 (2015-09-09)

- update weave to 1.1.0
- add dns entry for etcd
- `kontena registry create` cloud provider fixes
- use host networking in cadvisor
- service network stats fix
- fix multivalue handling in `kontena service deploy` command

## 0.8.1 (2015-09-01)

- fix digitalocean node provision dns issue
- fix failed nodes not detected under some circumstances
- fix deploy -p with empty string
- fix error in container exec command
- fix error in setting node labels
- fix service name validation (do not allow dash as a first char)

## 0.8.0 (2015-08-30)

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

## 0.7.4 (2015-08-15)

- Fix etcd boot errors on flaky networks

## 0.7.3 (2015-07-26)

- Fix `kontena deploy` regression
- Fix cli service id handling

## 0.7.2 (2015-07-25)

- Fix installation error when eth1 is not present on agent node
- Change default initial grid size to 1

## 0.7.1 (2015-07-24)

- Ubuntu packages docker dependency fix
- Database indexing fix
- Containers api fix

## 0.7.0 (2015-07-22)

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

## 0.6.1 (2015-06-01)

- Improve `kontena container exec`
- Fix unexpected behaviour in agent container exec calls
- Fix weave-helper to catch already running containers

## 0.6.0 (2015-05-25)

- New cli command: `kontena deploy`
- New cli commands for managing OpenVPN server
- Weave network configuration improvements
- Server & Agent images are now based on Alpine Linux
- Allow user to register even without access to server
- Resolve public ip of grid node
- Improved high-availability scheduling strategy
- Automatic lost node cleanup routine
- Show container id (with color) in service logs

## 0.5.0 (2015-05-02)

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
