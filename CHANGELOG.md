# Changelog

## [1.5.0](https://github.com/kontena/kontena/releases/tag/v1.5.0) (2018-02-28)

### Version 1.5 Highlights

#### Security Improvements

The Kontena Vault now uses a stronger key derived from the configured `VAULT_KEY` for encrypting vault secrets. The configured `VAULT_KEY` was previously truncated to the first 32 bytes, limiting the effective AES-CBC key strength to 128 bits for hexadecimal values, or 192 bits for base64-encoded values. Existing vault secrets will be re-encrypted using the stronger key on upgrade. (PR [#3248](https://github.com/kontena/kontena/pull/3248) / Issue [#3247](https://github.com/kontena/kontena/issues/3247])

The Kontena Vault secrets are now encrypted using a random AES-CBC Initialization Vector (IV) that is randomized for each secret. The configured `VAULT_IV` was previously used as a static IV shared across all encrypted secrets, but is no longer required. Existing vault secrets will be re-encrypted using randomized IVs on upgrade. (PR [#3184](https://github.com/kontena/kontena/pull/3184) / Issue [#3183](https://github.com/kontena/kontena/issues/3183)

A potential XSS vulnerability in the "kontena master login --remote" code display has been fixed. ([#3223](https://github.com/kontena/kontena/pull/3223))

#### Options After Parameters

Commands that accept parameters now accept options also after the parameter. For example,
these commands did not work before:

```
$ kontena stack deploy example-stack --help
ERROR: too many arguments
$ kontena stack rm example-stack --force
ERROR: too many arguments
```

Note that if you need to use something that looks like an option as a parameter you need to use the
common double dash `--` option break indicator:

```
$ kontena master ssh -- ls -al
ERROR: Unrecognised option '-l'
$ kontena master ssh -- ls -al
$ kontena vault write -- SECRET --secret-password--
```

#### Kontena Stack Registry V2 API And The New 'meta' Fields

While mostly invisible to the end-user, the CLI stack registry API client is now using
the completely rewritten stack registry and the V2 JSON-API it offers. The registry
supports GZip responses, private stacks, server-side stack YAML validation and parsing
of the new top level 'meta:' fields.

The meta fields can be used to add extra information to stacks published in the registry.

You can find the full set of accepted metadata fields in the pull request #3219 description.

As the CLI HTTP client now supports gzip compressed responses, we have also added the option
to enable compression in the Kontena Master API. To enable, set `KONTENA_SERVER_GZIP=true`
in the Master environment.

#### Drop Support For Ruby 2.1, Build Installer With Embedded Ruby 2.5.0

As Ruby 2.1 branch has been out of development for almost a year now, it's time to upgrade
if you already didn't.

The MacOS Kontena CLI installation package is now bundled with Ruby version 2.5.0

Ruby 2.2 is nearing its EOL at the end of March 2018.

#### Process Multiple Items In One Command

Many of the subcommands can now accept a list of items instead of just one. This is handy in
shell scripts and one-liners, for example:

```
$ kontena vault ls -q | xargs kontena vault rm --force
$ kontena vault rm --force $(kontena vault ls -q)
```

#### Master Authentication Token Descriptions

You can now add descriptions to the master authentication tokens:

```
$ kontena master token create -e 0 --description "deploy key"
$ kontena master token ls
ID                         TOKEN_TYPE   TOKEN_LAST4   EXPIRES_IN   SCOPES       DESCRIPTION
5a8c275351d1a1001566a4ef   bearer       f539          never        user         deploy key
```

#### Health Check

The agent now uses the port in health check definition when configuring the load balancer. (PR [#3113](https://github.com/kontena/kontena/pull/) / Issue [#1709](https://github.com/kontena/kontena/issues/1709))

Example configuration:

```
    health_check:
      protocol: http
      uri: /
      port: 8000
```

The health check will now consider HTTP 3XX status codes as healthy. (PR [#3265](https://github.com/kontena/kontena/pull/3265) / Issue [#1790](https://github.com/kontena/kontena/issues/1790))

#### Logging Service Instance Crash Events

The kontena service events now include an `instance_crash` event for service containers that exit unexpectedly. Compared to the existing `start_instance` events, these events do not get logged for service deploys or manual service restarts. ([#3286](https://github.com/kontena/kontena/pull/3286))

```
TIME                      TYPE                 MESSAGE
...
2018-02-16T12:38:38.583Z  instance_crash       service test/client-1 instance exited with code 1, restarting (delay: 0s) (core-01)
```

#### Service Affinities

When scheduling a service with an affinity like `service==api` affinity, only the bare service names were previously matched without considering their stack scope. If multiple stacks had identically named services that match the affinity filter, then all of those external services would have been considered as matching candidates. (PR [#2967](https://github.com/kontena/kontena/pull/2967) / Issue [#2911](https://github.com/kontena/kontena/issues/2961))

You can define a stack scoped affinity rule that matches a service in another stack as `service==stack-b/api`. A service affinity filter such as `service==api` will now only match a service named `api` within the same stack.

The affinity filters can now also include regular expressions such as `node!=/^node-(2|3)$/`. (PR [#3099](https://github.com/kontena/kontena/pull/3099) / Issue [#2909](https://github.com/kontena/kontena/issues/2909))

#### Daemon Strategy Node Stickiness

When a service has been deployed using the daemon strategy and a node goes offline, the scheduler now keeps the existing instances on the nodes they were running on already. ([#3137](https://github.com/kontena/kontena/pull/3137))

Node|All Online  |Node 2 Offline Before 1.5|Node 2 Offline With Kontena 1.5
----|------------|-------------------------|-----------------------------------
 1  | instance-1 | instance-1              | instance-1
 2  | instance-2 |                         |
 3  | instance-3 | instance-2              | instance-3
 4  | instance-4 | instance-3              | instance-2

#### Let's Encrypt Certificate Challenges

The Kontena Let's Encrypt certificate integration now supports http-01 challenges as a replacement for the disabled tls-sni-01 challenges. (PR [#3212](https://github.com/kontena/kontena/pull/3212) / Issue [#3209](https://github.com/kontena/kontena/issues/3209))

### Changes

#### Agent
* Add health check port to LB configs ([#3113](https://github.com/kontena/kontena/pull/3113))
* Add Agent Watchdog supervisor to agent ([#3135](https://github.com/kontena/kontena/pull/3135))
* Fix agent ServicePodWorker to ignore stale container events ([#3259](https://github.com/kontena/kontena/pull/3259))
* Change agent health check to accept HTTP 3xx as healthy ([#3265](https://github.com/kontena/kontena/pull/3265))
* Log container healthcheck errors ([#3284](https://github.com/kontena/kontena/pull/3284))
* Log service:instance_exit event on container crashes ([#3286](https://github.com/kontena/kontena/pull/3286))
* Fix agent to unregister LB service backends earlier during container shutdown ([#3287](https://github.com/kontena/kontena/pull/3287))
* Fix agent container log dropping entries when queue size exactly matches the throttle limit ([#3288](https://github.com/kontena/kontena/pull/3288))

#### Agent + Server
* Use GridService revision for service/container updates ([#2371](https://github.com/kontena/kontena/pull/2371))
* Improve agent ServicePodWorker container restart handling ([#2780](https://github.com/kontena/kontena/pull/2780))

#### Server
* Remove server AsyncHelper#async_thread ([#2786](https://github.com/kontena/kontena/pull/2786))
* Fix service affinity filters to be stack-scoped ([#2967](https://github.com/kontena/kontena/pull/2967))
* Cap stack/service deploy collections ([#3041](https://github.com/kontena/kontena/pull/3041))
* Deploy tls-sni challenge certs as separate SSL_CERT_acme_challenge_* envs ([#3076](https://github.com/kontena/kontena/pull/3076))
* Support regex in affinity filters ([#3099](https://github.com/kontena/kontena/pull/3099))
* Remove dependant service logic ([#3100](https://github.com/kontena/kontena/pull/3100))
* Validate tls-sni domain authorization linked service port ([#3132](https://github.com/kontena/kontena/pull/3132))
* Enhance daemon strategy to implement node stickiness ([#3137](https://github.com/kontena/kontena/pull/3137))
* Use random initialization vector ([#3184](https://github.com/kontena/kontena/pull/3184))
* Fix server certificate domain verification request error handling ([#3186](https://github.com/kontena/kontena/pull/3186))
* Add cleaner job for old deployments ([#3191](https://github.com/kontena/kontena/pull/3191))
* Remove deprecated GridServiceHealthMonitorJob ([#3202](https://github.com/kontena/kontena/pull/3202))
* Resolve notification message receivers properly when grid is deleted ([#3214](https://github.com/kontena/kontena/pull/3214))
* Fix server Celluloid::Proxy::Async<MongoPubsub> leak from RPC /container/health handler ([#3217](https://github.com/kontena/kontena/pull/3217))
* Fix server MongoPubsub to restart subscriptions after crashing ([#3218](https://github.com/kontena/kontena/pull/3218))
* Fix potential XSS vulnerability in master remote login code display ([#3223](https://github.com/kontena/kontena/pull/3223))
* Enable server API gzip encoding when KONTENA_SERVER_GZIP=true ([#3241](https://github.com/kontena/kontena/pull/3241))
* Server: Derive stronger SymmetricEncryption key from the configured VAULT_KEY ([#3248](https://github.com/kontena/kontena/pull/3248))
* Change GridService.stop_grace_period to Integer ([#3275](https://github.com/kontena/kontena/pull/3275))
* Upgrade server api-docs build system nokogiri to 1.8.2 ([#3309](https://github.com/kontena/kontena/pull/3309))

#### Server + CLI
* Make --email optional in external-registry add ([#3055](https://github.com/kontena/kontena/pull/3055))
* Add description field to master authentication access tokens ([#3211](https://github.com/kontena/kontena/pull/3211))
* Basic support for Let's Encrypt http-01 certificate / domain authorizations ([#3212](https://github.com/kontena/kontena/pull/3212))
* Send and return stack metadata to/from master ([#3281](https://github.com/kontena/kontena/pull/3281))

#### CLI
* Add "kontena plugin upgrade" to upgrade all plugins ([#2952](https://github.com/kontena/kontena/pull/2952))
* Set master name from KONTENA_MASTER when configuring from ENV ([#3009](https://github.com/kontena/kontena/pull/3009))
* Require --force if some items in node label rm list are missing ([#3065](https://github.com/kontena/kontena/pull/3065))
* Use --no-log-forwarder instead of --log-forwarder none in grid update ([#3095](https://github.com/kontena/kontena/pull/3095))
* Add --id to "kontena master token current" ([#3096](https://github.com/kontena/kontena/pull/3096))
* Stack inspect command ([#3123](https://github.com/kontena/kontena/pull/3123))
* Make kontena master token show output consistent with other show commands ([#3156](https://github.com/kontena/kontena/pull/3156))
* Fix confirmation dialog in stack related commands ([#3169](https://github.com/kontena/kontena/pull/3169))
* Update CLI image docker client to 17.06 ([#3177](https://github.com/kontena/kontena/pull/3177))
* Remove deprecated "kontena master users" subcommand ([#3182](https://github.com/kontena/kontena/pull/3182))
* Refactor stack change resolving ([#3185](https://github.com/kontena/kontena/pull/3185))
* Fix stack list tree icon ([#3187](https://github.com/kontena/kontena/pull/3187))
* Improve stack install deps handling ([#3188](https://github.com/kontena/kontena/pull/3188))
* Don't warn about deps if --keep-dependencies is given in stack rm ([#3189](https://github.com/kontena/kontena/pull/3189))
* Allow to command multiple items via CLI ([#3193](https://github.com/kontena/kontena/pull/3193))
* Remove deprecated app subcommand from CLI completions ([#3195](https://github.com/kontena/kontena/pull/3195))
* Fix and enhance stack command CLI autocompletions ([#3197](https://github.com/kontena/kontena/pull/3197))
* Upgrade CLI tty-prompt dependency to 0.14.0 ([#3203](https://github.com/kontena/kontena/pull/3203))
* Upgrade CLI excon dependency to 0.60.0 ([#3204](https://github.com/kontena/kontena/pull/3204))
* Upgrade CLI hash_validator dependency to 0.8.0 ([#3205](https://github.com/kontena/kontena/pull/3205))
* Drop CLI launchy dependency ([#3208](https://github.com/kontena/kontena/pull/3208))
* Switch to Stack registry V2 API and add support the new stack YAML metadata fields ([#3219](https://github.com/kontena/kontena/pull/3219))
* Enable gzip response parsing in CLI API client where supported ([#3222](https://github.com/kontena/kontena/pull/3222))
* Fix cli plugin uninstall ([#3230](https://github.com/kontena/kontena/pull/3230))
* Add missing cli etcd remove alias ([#3235](https://github.com/kontena/kontena/pull/3235))
* Fix client to not ignore invalid response JSON ([#3240](https://github.com/kontena/kontena/pull/3240))
* Fix to not accept gzip responses for streaming get requests ([#3242](https://github.com/kontena/kontena/pull/3242))
* Fix API client to ignore empty response JSON body ([#3252](https://github.com/kontena/kontena/pull/3252))
* Fix stack service extends: from registry stacks ([#3258](https://github.com/kontena/kontena/pull/3258))
* Fix grid remove parameter attribute conflict ([#3263](https://github.com/kontena/kontena/pull/3263))
* Upgrade CLI clamp dependency to 1.2.1 ([#3267](https://github.com/kontena/kontena/pull/3267))
* Allow CLI --options after parameters ([#3268](https://github.com/kontena/kontena/pull/3268))
* Drop CLI Ruby 2.1.0 support, upgrade installer embedded Ruby to 2.5.0 ([#3272](https://github.com/kontena/kontena/pull/3272))
* Fix stack / service deploy --no-wait description ([#3290](https://github.com/kontena/kontena/pull/3290))
* Add kontena service scale missing --no-wait flag ([#3298](https://github.com/kontena/kontena/pull/3298))
* Fix CLI master deploy wizard auth provider help links ([#3308](https://github.com/kontena/kontena/pull/3308))

#### Test suite
* Fix remaining plugin uninstall --force usages in tests ([#2935](https://github.com/kontena/kontena/pull/2935))
* Fix e2e stack validate entrypoint spec to use --format=api-json ([#3163](https://github.com/kontena/kontena/pull/3163))
* Fix e2e broken stack remove spec after hook ([#3164](https://github.com/kontena/kontena/pull/3164))
* Fix e2e test spec helpers to fail instead of aborting ([#3165](https://github.com/kontena/kontena/pull/3165))
* Fix e2e test container to use bundle exec ([#3170](https://github.com/kontena/kontena/pull/3170))
* Fix e2e stack validate entrypoint spec ([#3172](https://github.com/kontena/kontena/pull/3172))
* Test cli with ruby-2.5.0 ([#3175](https://github.com/kontena/kontena/pull/3175))
* Add --profile to e2e suite .rspec ([#3198](https://github.com/kontena/kontena/pull/3198))
* Fix travis e2e allow_failures clause ([#3199](https://github.com/kontena/kontena/pull/3199))
* Optimize e2e vpn specs ([#3200](https://github.com/kontena/kontena/pull/3200))
* Fix e2e stack install spec stack conflicts ([#3201](https://github.com/kontena/kontena/pull/3201))
* Fix e2e remove specs to not use unsupported shell syntax ([#3227](https://github.com/kontena/kontena/pull/3227))
* Fix e2e specs to run! (some of) the things ([#3229](https://github.com/kontena/kontena/pull/3229))
* Require travis e2e specs to pass ([#3232](https://github.com/kontena/kontena/pull/3232))
* E2E: Add spec for master token remove ([#3233](https://github.com/kontena/kontena/pull/3233))
* E2E: Use run! where applicable ([#3236](https://github.com/kontena/kontena/pull/3236))
* Fix hanging stack upgrade e2e spec ([#3244](https://github.com/kontena/kontena/pull/3244))
* Fix e2e app remove spec race on terminating service ([#3245](https://github.com/kontena/kontena/pull/3245))
* Fix CLI travis to bundle install --without development ([#3221](https://github.com/kontena/kontena/pull/3221))
* Fix flaky agent EventWorker#start spec ([#3305](https://github.com/kontena/kontena/pull/3305))

## [1.4.3](https://github.com/kontena/kontena/releases/tag/v1.4.3) (2017-12-20)

The 1.4.3 release fixes regressions in the 1.4 releases, as well as some other issues.

### Fixed issues

* Volume create fails if driver-opt contains dots #3125
* Stack depends mutates ${STACK} #3144
* Service instances resolver throws error #3145
* Kontena stack registry push prompts for variable values #3102
* Kontena master token current --expires-in shows negative number for still valid token #3153
* Server rejects TTY exec with zero console width or height, breaking e2e specs and the Kontena Cloud Terminal #3060
* Container exec with TTY fails with Celluloid::TaskTerminated on tty resize #3140
* CLI plugin loading is broken with DEBUG=plugins #3149
* CLI: cloud subcommand error message unclear without plugin #3097
* CLI exec fails with ERROR undefined method 'raw' for #<IO:<STDIN>> (NoMethodError) #3160

### Changes

#### Agent

* Fix agent ContainerExec to handle any kind of docker error during tty resize ([#3141](https://github.com/kontena/kontena/pull/3141))

#### Server

* Allow to pass dotted volume driver-opt keys ([#3126](https://github.com/kontena/kontena/pull/3126))
* Relax server exec API to accept tty_resize with zero width/height ([#3147](https://github.com/kontena/kontena/pull/3147))

#### CLI

* Fix CLI exec to use TTY::Screen.size ([#3139](https://github.com/kontena/kontena/pull/3139))
* Fix DEBUG=plugin Kontena::PluginManager::Loader#report_tracking ([#3150](https://github.com/kontena/kontena/pull/3150))
* CLI: Mark certificate get as deprecated in certificate sub-command list ([#3131](https://github.com/kontena/kontena/pull/3131))
* Fix stack commands not to modify STACK/GRID env of parent when installing child stacks ([#3146](https://github.com/kontena/kontena/pull/3146))
* Fix stack yaml from: service_instances resolver ([#3157](https://github.com/kontena/kontena/pull/3157))
* Remove --values-from and prompts from kontena stack registry push ([#3158](https://github.com/kontena/kontena/pull/3158))
* Fix negative number in kontena master token current --expires-in ([#3154](https://github.com/kontena/kontena/pull/3154))
* Suggest plugin install when using known cloud plugin subcommands ([#3098](https://github.com/kontena/kontena/pull/3098))
* Fix missing require for cli exec use of STDIN.raw ([#3161](https://github.com/kontena/kontena/pull/3161))

## [1.4.2](https://github.com/kontena/kontena/releases/tag/v1.4.2) (2017-12-08)

The 1.4.2 release fixes regressions in the 1.4.0 and 1.4.1 releases, as well as some other issues.

### Fixed issues

* kontena certificate register Let's Encrypt TOS link is out of date #3105
* HTTP 404 Not Found error on kontena certificate register #3104
* kontena stack install fails in 1.4.1 with KONTENA_URL=... #3089
* CLI stack validate outputs stack create API request instead of interpolated stack YAML #2887
* cAdvisor queries missing containers over and over #2700

### Changes

#### Agent

* Agent: Bump cadvisor to 0.27.2 ([#3115](https://github.com/kontena/kontena/pull/3115))

#### Server

* Fix certificates API POST request routing ([#3107](https://github.com/kontena/kontena/pull/3107))
* Fix server to filter out node peer_ip duplicates ([#3112](https://github.com/kontena/kontena/pull/3112))

#### CLI

* Fix stack deploy to not raise RuntimeError on deploy errors ([#2931](https://github.com/kontena/kontena/pull/2931))
* CLI: Use a unique temp dir for specs instead of /tmp ([#3010](https://github.com/kontena/kontena/pull/3010))
* Fix CLI volume driver opts parsing ([#3101](https://github.com/kontena/kontena/pull/3101))
* Update CLI kontena certificate register Let's Encrypt ToS link ([#3106](https://github.com/kontena/kontena/pull/3106))
* Fix CLI stack validate to output either interpolated stack YAML or API JSON ([#2938](https://github.com/kontena/kontena/pull/2938))
* Fix CLI config to correctly load both master server and cloud account settings from envs or config file ([#3090](https://github.com/kontena/kontena/pull/3090))

## [1.4.1](https://github.com/kontena/kontena/releases/tag/v1.4.1) (2017-11-23)

**Master & Agents:**

* Fix agent to start container healthchecks for non-http protocols ([#3080](https://github.com/kontena/kontena/pull/3080))
* Fix server to only deploy pending/active domain authorization challenge certs ([#2994](https://github.com/kontena/kontena/pull/2994))
* Fix agent LogWorker to not exclusively block in start until websocket connected ([#3069](https://github.com/kontena/kontena/pull/3069))
* Fix performance issue in vault secrets listing ([#3061](https://github.com/kontena/kontena/pull/3061))
* Fix ping api to check that process is healthy ([#3036](https://github.com/kontena/kontena/pull/3036))
* Fix server websocket backend to not overwrite node labels on initial connection ([#2989](https://github.com/kontena/kontena/pull/2989))
* Fix server node connected events ([#2995](https://github.com/kontena/kontena/pull/2995))
* Fix server websocket exec error handling ([#2912](https://github.com/kontena/kontena/pull/2912))
* Fix server to omit container io.kontena.health_check.uri label for non-http health-check protocols ([#3023](https://github.com/kontena/kontena/pull/3023))
* Fix agent healthchecks to accept any HTTP 2xx response as healthy ([#3006](https://github.com/kontena/kontena/pull/3006))
* Fix POST /v1/grids/:grid/external_registries API error response ([#3043](https://github.com/kontena/kontena/pull/3043))
* Fix server RpcServer to be supervised and restart on crashes ([#3037](https://github.com/kontena/kontena/pull/3037))
* Allow configuring of Mongo ssl_verify and ssl_ca_cert through env ([#3071](https://github.com/kontena/kontena/pull/3071))
* Improve scheduler performance ([#2921](https://github.com/kontena/kontena/pull/2921))
* Server/Agent websocket client reconnect backoff ([#2916](https://github.com/kontena/kontena/pull/2916))
* Validate service env size limits ([#2951](https://github.com/kontena/kontena/pull/2951))
* Validate HostNode grid presence ([#3018](https://github.com/kontena/kontena/pull/3018))
* Add missing HostNode attributes to HostNodeSerializer ([#3017](https://github.com/kontena/kontena/pull/3017))
* Update mongo driver to 2.4.3 ([#3048](https://github.com/kontena/kontena/pull/3048))
* Kontena certificate import/export ([#2988](https://github.com/kontena/kontena/pull/2988))
* Mongo debug logging with DEBUG_MONGO=true ([#3049](https://github.com/kontena/kontena/pull/3049))

**CLI:**

* Fix exec --tty for valid non-ASCII unicode input ([#2900](https://github.com/kontena/kontena/pull/2900))
* Fix variable interpolation in extended stack files ([#2945](https://github.com/kontena/kontena/pull/2945))
* Fix command exception handling with DEBUG ([#2993](https://github.com/kontena/kontena/pull/2993))
* Fix cloud token env variable ([#3013](https://github.com/kontena/kontena/pull/3013))
* Fix kontena external-registry add to use https:// by default ([#3034](https://github.com/kontena/kontena/pull/3034))
* Fix certificate show output formatting ([#2966](https://github.com/kontena/kontena/pull/2966))
* Fix DEBUG=true with Kontena::Errors::StandardError ([#3024](https://github.com/kontena/kontena/pull/3024))
* Fix crash in kontena external registry ls -q ([#3051](https://github.com/kontena/kontena/pull/3051))
* Enable anchor/aliases support in YAML parsing ([#2771](https://github.com/kontena/kontena/pull/2771))
* Add stack variables certificates resolver ([#2990](https://github.com/kontena/kontena/pull/2990))
* Upgrade tty-table dependency to 0.9.0 ([#3015](https://github.com/kontena/kontena/pull/3015))
* Add support for entrypoint in stack files ([#2950](https://github.com/kontena/kontena/pull/2950))
* Turn off debugging by using DEBUG=false ([#2960](https://github.com/kontena/kontena/pull/2960))

**Other:**

* Add server API docs for the new certificates API ([#3011](https://github.com/kontena/kontena/pull/3011))
* Bump travis ruby to 2.4.2 ([#2944](https://github.com/kontena/kontena/pull/2944))
* Fix CLI specs to not give false positives on SystemExit ([#3021](https://github.com/kontena/kontena/pull/3021))
* Use bundle audit to check gem vulnerabilities ([#3047](https://github.com/kontena/kontena/pull/3047))
* Docs: Fix broken JSON Attributes table in index.html.md ([#3078](https://github.com/kontena/kontena/pull/3078))
* Docs: certificate, domain authz API JSON fields ([#3077](https://github.com/kontena/kontena/pull/3077))

## [1.4.0](https://github.com/kontena/kontena/releases/tag/v1.4.0) (2017-10-16)

### Highlights

#### Fully automated LetsEncrypt certificates using `tls-sni-01`

The new Kontena Certificate support integrates with the Kontena Loadbalancer to provide fully automated Let's Encrypt `tls-sni-01` domain authorizations.

The `kontena certificate authorize` command can be used to request a **tls-sni-01** domain authorization challenge from Let's Encrypt, and also deploy the challenge certificate to the linked Kontena load-balancer. The new `kontena certificate request` command can then be immediately used to request a new certificate for the authorized domains. The new certificates will show up in `kontena certificate list` together with their validity period, and the Kontena Master will automatically renew the certificates 7 days before expiry.

These new certificates can be deployed to the load-balancer service using the new Kontena Stack YAML `certificates` syntax.

```yaml
stack: example/lb
services:
  lb:
    image: kontena/lb
    certificates:
      - subject: example.com
```

Any existing `LE_CERTIFICATE_*` secrets will also be migrated to Kontena Certificates during the upgrade.

#### Stack dependencies

Kontena Stacks can now embed other Kontena Stacks, and these child stacks will be automatically installed, upgraded and removed as part of the top-level stack. The child stack variables can either be set by the parent stack, or using the new `kontena stack install -v child.variable=value` CLI options.

```yaml
stack: example/app
depends:
  db:
    stack: example/db
services:
  app:
    image: example/app
    env:
      - DB=$db.$GRID.kontena.local
```

### CLI changes

* `kontena app`

    The deprecated `app` commands have been moved into a separate plugin: `kontena plugin install app-command`.

* `kontena cloud platform|organization|region`

    The new `kontena cloud` commands are included in the `cloud` plugin: `kontena plugin install cloud`.

    The `cloud` plugin is included in the CLI installer packages.

* `kontena node list`

    The node `status` shows additional states including `connecting` and `drain`. It also shows how long the node has been online/offline for.

* `kontena node create`

    Kontena Nodes can provisioned using per-node tokens as an alternative to the current per-grid tokens. The `kontena node create` command can be used to create a node with a generated node token for manual provisioning.

* `kontena node update --availability=drain`

    Nodes can be placed into the `drain` state, where no new service instances will be scheduled onto the node, any stateless service instances will be re-scheduled onto other nodes, and stateful service instances will be stopped.

    Use `kontena node update --availability=active` to restore the node into active use. Stateful service instances will be re-started, and stateless services will be re-balanced to deploy back onto the node.

* `kontena node reset-token`

    Kontena Nodes provisioned using per-node tokens can have their node tokens reset. This can also be used to convert nodes to use per-node tokens, or revert back to grid tokens.

    This will also disconnect any agents connected using the old node token, and prevent any agents from reconnecting using the old node token. The node must be manually reconfigured to use the new node token.

* `kontena node remove`

    The `kontena node remove` command can now be used to remove online nodes if they were provisioned using per-node tokens, disconnecting the agent.

    Nodes using grid tokens cannot be removed if they are still online.

* `kontena node health`

    The `kontena node health` command shows more information about any websocket connection errors, and also shows grid `etcd` health.

* `kontena node env`

    Generate the `/etc/kontena-agent.env` configuration required for manual provisioning of nodes using per-node tokens.

* `kontena grid create --statsd-server --log-forwarder`

    The `kontena grid create` command now supports the same `--statsd-server`, `--log-forwarder` and `--log-opt` options previously only supported in `kontena grid update`.

* `kontena grid|stack|service|container logs|events -f --tail`

    The `kontena * logs` and `kontena * events` commands have been changed to to use `--follow` `--tail=N` options.

* `kontena stack install -v foo=bar`

    Provide values for stack variables when installing, skipping any prompts. Similar to `--values-from`.

    Use `-v foo.var=bar` to provide values for the `depends: foo` child stack `variables`.

* `kontena stack install|upgrade|build|validate --values-from-stack`

    Copy variable values from an installed stack.

* `kontena stack upgrade --dry-run`

    Show services and child stack dependencies that would added, removed and upgraded without actually affecting the installed stacks on the server.

* `kontena stack|service deploy --no-wait`

    Trigger a stack/service deploy without waiting for it to complete.

* `kontena stack logs STACK [SERVICE...]`

    The `kontena stack logs` command can be used to show logs for specific services in the stack.

* `kontena stack show --values --values-to`

    The `kontena stack show` output also includes the stack variable values as stored on the server, and used for upgrades.

    The `--values` and `--values-to` options can be used to display/store these separately.

* `kontena service|container exec`

    The CLI exec commands and websocket client have been rewritten to be more robust.

    The interactive `--tty` execs now run with the correct terminal size.

* `kontena certificate list`

    List certificates obtained using the new `kontena certificate request` command.

    The server will automatically renew any expiring certificates if the all domains were authorized with `--type tls-sni-01` (listed as auto-renewable). The auto-renewal job will automatically deploy the new domain authorization challenge certificates and the renewed certificates to the linked loadbalancer service.

* `kontena certificate show`

* `kontena certificate register --agree-tos`

    The `kontena certificate register` command now prompts for the LetsEncrypt Terms of Service. Use the `--agree-tos` to accept the TOS programmatically.

* `kontena certificate authorize --type tls-sni-01 --linked-service`

    Use the new integrated Kontena Loadbalancer support to request a LetsEncrypt `tls-sni-01` challenge, and automatically deploy the challenge cert to the linked load balancer.

    Certificates using domains authorized with `tls-sni-01` challenges can be requested using `kontena certificate request` without any intervening manual steps, and will also be automatically renewed by the server.

    The default `kontena certificate authorize --type` remains `dns-01`, which requires the DNS challenge records to be deployed manually.

* `kontena certificate request`

    The new `kontena certificate request` command replaces the deprecated `kontena certificate get` command. Certificates obtained using the new `kontena certificate request` command will show up in `kontena certificate list`, and can be deployed to stack services using the new `certificates: - subject: ...` stack YAML.

    Certificates obtained using `kontena certificate request` will not show up as secrets in `kontena vault list`.

* `kontena certificate get` (deprecated)

    The `kontena certificate get` command is retained to support services using the existing `secret: - name: LE_CERTIFICATE_*` stack YAML, but is deprecated in favor of the new `kontena certificate request` command.

    Certificates obtained in the form of `kontena vault` secrets using `kontena certificate get` will not show up in `kontena certificate list`, and will not be auto-renewed by the server.

* `kontena certificate delete`

    Remove a certificate that is no longer in use by any services.

    Cleanup unused certificates to prevent the certificate auto-renewal from unnecessarily consuming LetsEncrypt rate-limits.

* `kontena registry create`

    The `--s3-v4auth` optional is now the default.

* `kontena volume list -q`

    Output the plain volume name `foo` used for scripting `kontena volume ...` commands, instead of the full `gridname/foo` ID.

* `kontena plugin uninstall`

    No longer prompts for confirmation or accepts `--force`.

### Service / Stack YAML changes

New Kontena Stack YAML variables, attributes and `kontena service create|update` options:

* `$PLATFORM`

    Stack YAML files can also interpolate the `$PLATFORM` variable, which matches the `$GRID`.

* Soft `affinity`: `==~`

    Normal "hard" affinities will fail the service deploy if the scheduler cannot satisfy the condition. The scheduler will attempt to satisfy soft affinities, but will ignore them if unable to. Typically used for negative affinities two avoid scheduling services onto the same node if possible.

* `cpus` / `--cpus`

    Limit the maximum CPU utilization of a service containers.

* `certificates`

    Deploy certificates generated using `kontena certificate request` to services, similarly to the `LE_CERTIFICATE_*_BUNDLE` secrets.

    ```yaml
    services:
      lb:
        image: kontena/lb
        certificates:
          - subject: example.com
            name: SSL_CERTS
    ```

    Only certificates available in `kontena certificate list` can be deployed this way.

* `hooks`: `type: post_start`

    The service `post_start` hooks are now run on every container start, not just when deploying containers. This happens on deploys that (re)create the container, `kontena service start`, or when the container process exits and is restarted by the agent.

    The `post_start` hooks do not run on `kontena service restart`,
    or on healthcheck restarts.

* `hooks`: `type: pre_start`

    The new `pre_start` hooks run before every container start. This happens on deploys that (re)create the container, `kontena service start`, or when the container process exits and is restarted by the agent.

    The `pre_start` hooks are run in a separate container, with the service image, envs and volumes. Changes to the container overlay filesystem in `pre_start` hooks are not preserved, and the `pre_start` hooks run with a different overlay network address than the service container.

    The `pre_start` hooks do not run on `kontena service restart`,
    or on healthcheck restarts.

* `hooks`: `type: pre_stop`

    The new `pre_stop` hooks run before every container stop. This happens on deploys that (re)create the container, `kontena service stop`, and when the service is scaled down or removed.

    The `pre_stop` hooks do not run on `kontena service restart`,
    or on healthcheck restarts.

* `read_only` / `--read-only`

    The container overlay filesystem from the Docker image is mounted readonly, and only explicit volume mounts can be written to.

* `shm_size` / `--shm-size`

    Override the default 64MB `/dev/shm` size for service containers.

* `stop_grace_period` / `--stop-timeout`

    Timeout in seconds for stopping the container.

* `stop_signal` / `--stop-signal`

    Override the default `SIGTERM` signal used to stop a container.

### Breaking changes

* Docker versions older than 1.12 are no longer supported on host/master nodes ([#2589](https://github.com/kontena/kontena/pull/2589))

    Docker versions from 1.12 (CoreOS stable) to 17.06 (CoreOS alpha) are supported.

* Service `post_start` hooks now run on every container start, not just when deploying ([#2701](https://github.com/kontena/kontena/pull/2701))

    Existing service `post_start` hooks used to only run on service deploys that (re)created the service container. The existing `post_start` and new `pre_start` hooks are now also run on each `kontena service start`, or when the container process exits and is restarted by the agent.

    This does not affect `oneshot: true` hooks, which are still only executed once when the container is first started.

* The CLI `kontena {container,service,stack} {logs,events}` options have changed ([#2046](https://github.com/kontena/kontena/pull/2046))

    The old Heroku-style `--lines=N --tail` options have been replaced by `--tail=N --follow` matching the options used by most other common tools.

* Stack variables are no longer `to: env` by default ([#2802](https://github.com/kontena/kontena/pull/2802))

    Stack variables can always be interpolated using `$foo` within the same stack file, but are no longer (by default) exposed to other dependent stacks, other variables using `from: env`, or any processes spawned by the CLI.

    Variables can still use `to: env` explicitly, or the new `from: variable` resolver.

* API node `id` field has been changed to use `:grid/:node` ([#2483](https://github.com/kontena/kontena/pull/2483))

    The API used to return node IDs in the form of `{"id": "CAR3:26...AB:6Y3Q"}`. The API responses have been changed to return nodes in the form of `{"id": ":grid/:name", "node_id": "..."}` to match the other APIs.

### Deprecations

* The `kontena certificate get` command has been deprecated ([#2736](https://github.com/kontena/kontena/pull/2736))

    The old `secrets`-based `kontena certificate get` workflow (using `name: LE_CERTIFICATE_example.com_BUNDLE`) has been replaced by the new `certificate`-based workflow (using `subject: example.com`). Certificates created using `kontena certificate request` are visible in `kontena certificate list`, and can be referred to by stack services using `certificates` -> `subject: ...`.

### Known issues

* Agent ServicePodWorker gets confused by service restarts ()#2781)
* Dependent stack variables are not interpolated ([#2799](https://github.com/kontena/kontena/pull/2799))

    The new stack `depends` do not yet support the use of interpolation for the child stack `variables`.

* CLI stack validate outputs stack create API request instead of interpolated stack YAML #2887

### Fixed issues

* Node evacuate #1030
* Agent Weave unnecessarily calls weaveexec launch-router, and logs error #1397
* Set node labels from kontena-container labels #1771
* Missing CLI omnibus package for Ubuntu #1954
* Race condition on reserve_node_number with concurrent node creates #2071
* kontena-agent needs a restart to notice new v1 volume plugins #2237
* Upgrade to Alpine 3.6 #2374
* agent: sometimes agent does not remove containers causing deploys to fail #2415
* Allow to set node name via environment variable #2465
* stateful: true service should not get deployed on instances with ephemeral[=yes] label #2487
* Soft affinity for services ([#2490](https://github.com/kontena/kontena/pull/2490))
* Agent does not validate KONTENA_URI=wss:// SSL certs ([#2500](https://github.com/kontena/kontena/pull/2500))
* CLI: kontena stack build to read values from installed stack #2515
* Raise weave connection limit ([#2539](https://github.com/kontena/kontena/pull/2539))
* Difficult to get rid of a node that is missing a name and stuck as (initializing) #2558
* Return also unhealthy count in service json ([#2564](https://github.com/kontena/kontena/pull/2564))
* Ubuntu kontena-agent package is not compatible with Docker 17.06 ([#2588](https://github.com/kontena/kontena/pull/2588))
* Move app commands to plugin ([#2597](https://github.com/kontena/kontena/pull/2597))
* Agent container exec only returns exit code 0 on Docker API errors #2598
* Cli exec does not set terminal size #2601
* CLI validation of wss:// SSL certs for exec commands is broken #2603
* (Docs) Default command for s3 image registry fails ([#2606](https://github.com/kontena/kontena/pull/2606))
* Add platform as grid alias in stack yml ([#2633](https://github.com/kontena/kontena/pull/2633))
* Expose platform name as env ([#2634](https://github.com/kontena/kontena/pull/2634))
* CLI timeout is too low ([#2637](https://github.com/kontena/kontena/pull/2637))
* LogWorker shouldn't spam docker logs #2661
* Server Cloud::WebsocketClient does not validate SSL certificates ([#2685](https://github.com/kontena/kontena/pull/2685))
* CLI: stack logs by service #2712
* 1.3 Agent stuck connecting to master ([#2723](https://github.com/kontena/kontena/pull/2723))
* Make fluentd forwarded logs more structured by default ([#2735](https://github.com/kontena/kontena/pull/2735))
* Agent container exec input can block the entire RPC server #2740
* kontena node/labels update does not notify nodes ([#2746](https://github.com/kontena/kontena/pull/2746))
* Support async stack deployments #2757
* Support for shm size #2764
* Server stack remove fails to stop services #2777
* Having a dry-run option for stack upgrade would be great #2819
* Service oneshot hooks might not get executed if the initial service deploy fails #2844
* Service oneshot hooks can get executed more than once in special circumstances #2845
* Remove experimental status from volume commands #2857
* CLI: ls -q outputs headers when result set empty #2874
* Server leaks memory if new containers are constantly created and destroyed #2895
* Certificate auto-renewal can fail if domain authz's linked service has been removed bug server #2881
* CLI: kontena volume ls -q returns grid/volumename #2925

### Changes

Commits that affect multiple components are listed separately under each affected component.

#### Agent

* Fix Etcd launcher to tolerate docker errors better ([#2509](https://github.com/kontena/kontena/pull/2509))
* Add configurable stop timeout for services ([#2033](https://github.com/kontena/kontena/pull/2033))
* Run post_start hooks before wait for port ([#2543](https://github.com/kontena/kontena/pull/2543))
* Unlimited connections for weave ([#2547](https://github.com/kontena/kontena/pull/2547))
* Read-only container instances ([#2550](https://github.com/kontena/kontena/pull/2550))
* Create HostNode with per-node token for websocket auth ([#2504](https://github.com/kontena/kontena/pull/2504))
* Rewrite agent websocket client ([#2560](https://github.com/kontena/kontena/pull/2560))
* Ubuntu kontena-agent: Use /usr/bin/dockerd for compatibility with Docker 1.12 - 17.06 ([#2589](https://github.com/kontena/kontena/pull/2589))
* Configurable agent node ID, labels ([#2590](https://github.com/kontena/kontena/pull/2590))
* Agent: minimal update of ruby 2.4 dependencies ([#2629](https://github.com/kontena/kontena/pull/2629))
* agent: fix nil node_labels from Docker.info ([#2642](https://github.com/kontena/kontena/pull/2642))
* agent: fix websocket client to not deadlock on sync actor calls from on_pong ([#2650](https://github.com/kontena/kontena/pull/2650))
* Update agent to ruby 2.4 ([#2630](https://github.com/kontena/kontena/pull/2630))
* Fix agent Docker.info caching ([#2676](https://github.com/kontena/kontena/pull/2676))
* Agent: Allow overriding KONTENA_NODE_NAME ([#2693](https://github.com/kontena/kontena/pull/2693))
* Agent: Upgrade docker-api gem to 1.33.6 ([#2695](https://github.com/kontena/kontena/pull/2695))
* Agent: upgrade vmstat to 2.3.0 ([#2696](https://github.com/kontena/kontena/pull/2696))
* Always create HostNode with unique name and node_number ([#2694](https://github.com/kontena/kontena/pull/2694))
* agent: have SIGTTIN handler use Celluloid.dump ([#2727](https://github.com/kontena/kontena/pull/2727))
* Fix agent websocket disconnected notifications ([#2725](https://github.com/kontena/kontena/pull/2725))
* agent: have SIGTTIN handler also dump non-celluloid threads ([#2742](https://github.com/kontena/kontena/pull/2742))
* Fix agent LogWorker start/stop ([#2728](https://github.com/kontena/kontena/pull/2728))
* Fix agent container exec input RPC hang ([#2743](https://github.com/kontena/kontena/pull/2743))
* Add metadata to fluent event hash ([#2738](https://github.com/kontena/kontena/pull/2738))
* agent: report container exec errors ([#2745](https://github.com/kontena/kontena/pull/2745))
* Fix Agent ServicePodWorker#container_outdated? to fail if service updated_at is in the future ([#2304](https://github.com/kontena/kontena/pull/2304))
* Don't start weave if it's already running ([#2760](https://github.com/kontena/kontena/pull/2760))
* Add rbtrace support to server & agent ([#2528](https://github.com/kontena/kontena/pull/2528))
* Send & store logs in batches ([#2750](https://github.com/kontena/kontena/pull/2750))
* Implement container restart policies in the agent ServicePodWorker ([#2689](https://github.com/kontena/kontena/pull/2689))
* Service cpus limit ([#2541](https://github.com/kontena/kontena/pull/2541))
* Fix agent ServicePodWorker to ignore old container events ([#2773](https://github.com/kontena/kontena/pull/2773))
* Implement synchronous Observers and lightweight Observables ([#2704](https://github.com/kontena/kontena/pull/2704))
* Fix agent ServicePodWorker to not block on wait_for_port ([#2776](https://github.com/kontena/kontena/pull/2776))
* Support shm_size ([#2767](https://github.com/kontena/kontena/pull/2767))
* Migrate restart-policy containers ([#2791](https://github.com/kontena/kontena/pull/2791))
* Fix exec console size ([#2708](https://github.com/kontena/kontena/pull/2708))
* Fix oneshot hooks; Change post_start hooks to run on start; Add pre_start, pre_stop hooks ([#2701](https://github.com/kontena/kontena/pull/2701))
* Change log RPCs to use xmlschema timestamps with sub-second precision ([#2832](https://github.com/kontena/kontena/pull/2832))
* Support for stop_signal ([#2918](https://github.com/kontena/kontena/pull/2918))

#### Server

* server mongo: remove hardcoded read mode because it's default ([#2476](https://github.com/kontena/kontena/pull/2476))
* Fix healtcheck port validation to check port in unix port range ([#2496](https://github.com/kontena/kontena/pull/2496))
* Fix LE cert authorization mutation to fail gracefully if not yet registered ([#2497](https://github.com/kontena/kontena/pull/2497))
* server GridServices::Update: spec and fix multiple names for the same secret ([#2506](https://github.com/kontena/kontena/pull/2506))
* Server: Upgrade to Alpine 3.6, Ruby 2.4 ([#2456](https://github.com/kontena/kontena/pull/2456))
* Server: Upgrade rack & roda to latest version ([#2457](https://github.com/kontena/kontena/pull/2457))
* Server: upgrade puma to 3.9.1 ([#2458](https://github.com/kontena/kontena/pull/2458))
* Unify common grid create/update POST/PUT parameters ([#2488](https://github.com/kontena/kontena/pull/2488))
* Fix server .ruby-version ([#2527](https://github.com/kontena/kontena/pull/2527))
* Automatically determine volume driver version from installed plugins ([#2526](https://github.com/kontena/kontena/pull/2526))
* Fix any versioned kontena/lb:* image to resolve as an LB service, not just latest ([#2530](https://github.com/kontena/kontena/pull/2530))
* Server: Fix HostNode connected_at field to type: Time ([#2529](https://github.com/kontena/kontena/pull/2529))
* Fix mongoid last sort ([#2534](https://github.com/kontena/kontena/pull/2534))
* Add configurable stop timeout for services ([#2033](https://github.com/kontena/kontena/pull/2033))
* Use latest HostNodeStat entry when serializing host node ([#2555](https://github.com/kontena/kontena/pull/2555))
* Support basic authentication in auth provider userinfo request ([#2260](https://github.com/kontena/kontena/pull/2260))
* Ephemeral nodes should not get any stateful services ([#2549](https://github.com/kontena/kontena/pull/2549))
* Read-only container instances ([#2550](https://github.com/kontena/kontena/pull/2550))
* Fix usage of node IDs in CLI, server API JSON + docs ([#2483](https://github.com/kontena/kontena/pull/2483))
*  Fix server grids update notify ([#2585](https://github.com/kontena/kontena/pull/2585))
* Create HostNode with per-node token for websocket auth ([#2504](https://github.com/kontena/kontena/pull/2504))
* Fix grid user remove access check ([#2579](https://github.com/kontena/kontena/pull/2579))
* Add new user_admin role ([#2577](https://github.com/kontena/kontena/pull/2577))
* Server: dockerignore docs/ to optimize image build ([#2613](https://github.com/kontena/kontena/pull/2613))
* Ubuntu kontena-agent: Use /usr/bin/dockerd for compatibility with Docker 1.12 - 17.06 ([#2589](https://github.com/kontena/kontena/pull/2589))
* Configurable agent node ID, labels ([#2590](https://github.com/kontena/kontena/pull/2590))
* Update server/docs dependencies for ruby 2.4 ([#2632](https://github.com/kontena/kontena/pull/2632))
* Fix node token clear to use DELETE /v1/nodes/:id/token ([#2636](https://github.com/kontena/kontena/pull/2636))
* Prefer reading stats/logs from secondary db node ([#2646](https://github.com/kontena/kontena/pull/2646))
* Update agent to ruby 2.4 ([#2630](https://github.com/kontena/kontena/pull/2630))
* Add support for soft affinities ([#2540](https://github.com/kontena/kontena/pull/2540))
* Add platform name a.k.a grid name to container env and labels ([#2670](https://github.com/kontena/kontena/pull/2670))
* Remove unnecessary and thread unsafe request parsing in token auth ([#2684](https://github.com/kontena/kontena/pull/2684))
* Node scheduling availability ([#2306](https://github.com/kontena/kontena/pull/2306))
* Add unhealthy container counts to service API ([#2674](https://github.com/kontena/kontena/pull/2674))
* Always create HostNode with unique name and node_number ([#2694](https://github.com/kontena/kontena/pull/2694))
* Make stack logs accept service names as filters ([#2713](https://github.com/kontena/kontena/pull/2713))
* Server: Replace use of Celluloid::Future for async threads  ([#2699](https://github.com/kontena/kontena/pull/2699))
* Fix server node update grid notify ([#2747](https://github.com/kontena/kontena/pull/2747))
* agent: report container exec errors ([#2745](https://github.com/kontena/kontena/pull/2745))
* Container#status as running if it's running but previously oom_killed ([#2751](https://github.com/kontena/kontena/pull/2751))
* Return related services in secret json ([#2755](https://github.com/kontena/kontena/pull/2755))
* Add rbtrace support to server & agent ([#2528](https://github.com/kontena/kontena/pull/2528))
* Rewrite server cloud websocket client ([#2692](https://github.com/kontena/kontena/pull/2692))
* Send & store logs in batches ([#2750](https://github.com/kontena/kontena/pull/2750))
* Don't fetch too many log items in stream loop ([#2761](https://github.com/kontena/kontena/pull/2761))
* Service cpus limit ([#2541](https://github.com/kontena/kontena/pull/2541))
* Initial tls-sni support and new api for domain authorizations ([#2732](https://github.com/kontena/kontena/pull/2732))
* Fix server GridServices::Start/Stop to not use async_thread ([#2778](https://github.com/kontena/kontena/pull/2778))
* Fix server HostNode::Update/Remove mutations to not use async_thread ([#2783](https://github.com/kontena/kontena/pull/2783))
* Fix server Grids::Update mutation to not use async_thread ([#2784](https://github.com/kontena/kontena/pull/2784))
* Fix server MongoPubsub to rescue block errors, and not use async_thread ([#2785](https://github.com/kontena/kontena/pull/2785))
* Allow stacks to depend on other stacks ([#2707](https://github.com/kontena/kontena/pull/2707))
* New certificate model, API, service YAML ([#2736](https://github.com/kontena/kontena/pull/2736))
* Enhanced HostNode status, health ([#2511](https://github.com/kontena/kontena/pull/2511))
* Certificate auto renewal ([#2816](https://github.com/kontena/kontena/pull/2816))
* Force update and trigger automatic service deploys after cert update ([#2818](https://github.com/kontena/kontena/pull/2818))
* Fix missing certificates validation on service update ([#2824](https://github.com/kontena/kontena/pull/2824))
* Show certs with service details ([#2826](https://github.com/kontena/kontena/pull/2826))
* Support shm_size ([#2767](https://github.com/kontena/kontena/pull/2767))
* Validate total service DNS hostname+domain length ([#2376](https://github.com/kontena/kontena/pull/2376))
* Fix exec console size ([#2708](https://github.com/kontena/kontena/pull/2708))
* Fix HostNode index updates to single migration ([#2852](https://github.com/kontena/kontena/pull/2852))
* Fix oneshot hooks; Change post_start hooks to run on start; Add pre_start, pre_stop hooks ([#2701](https://github.com/kontena/kontena/pull/2701))
* Fix websocket agent version check ([#2855](https://github.com/kontena/kontena/pull/2855))
* Add cert delete API and CLI command ([#2850](https://github.com/kontena/kontena/pull/2850))
* Fix server NodeVolumeHandler to not be a Celluloid actor ([#2868](https://github.com/kontena/kontena/pull/2868))
* List auto-renewable certificates; Migrate existing LE cert secrets to new certificate models ([#2867](https://github.com/kontena/kontena/pull/2867))
* Add ID field to stack dependency relations in JSON response ([#2866](https://github.com/kontena/kontena/pull/2866))
* Change log RPCs to use xmlschema timestamps with sub-second precision ([#2832](https://github.com/kontena/kontena/pull/2832))
* Remove experimental status from volumes ([#2864](https://github.com/kontena/kontena/pull/2864))
* Fix server stack view to not crash for orphaned child stacks ([#2885](https://github.com/kontena/kontena/pull/2885))
* Fix server cloud event serializer to use HostNode#to_path as node id ([#2892](https://github.com/kontena/kontena/pull/2892))
* Fix server ContainerInfoMapper memory leak ([#2896](https://github.com/kontena/kontena/pull/2896))
* Check ports from scheduled instances ([#2910](https://github.com/kontena/kontena/pull/2910))
* Check service affinity via service instances ([#2911](https://github.com/kontena/kontena/pull/2911))
* Support for stop_signal ([#2918](https://github.com/kontena/kontena/pull/2918))
* Docs: Add stack depends parent/children fields to API documentation ([#2862](https://github.com/kontena/kontena/pull/2862))
* Fix certificates to not auto-renew if missing the linked service ([#2933](https://github.com/kontena/kontena/pull/2933))

#### CLI

* cli: fix stream_stdin_to_ws to only use STDIN.raw mode if tty exec ([#2499](https://github.com/kontena/kontena/pull/2499))
* Fix cli node list sorting, specs ([#2512](https://github.com/kontena/kontena/pull/2512))
* Unify common grid create/update POST/PUT parameters ([#2488](https://github.com/kontena/kontena/pull/2488))
* cli: change stacks deploy helper to wait on deployment state ([#2525](https://github.com/kontena/kontena/pull/2525))
* cli: update grid cloud-config to use [Link] Unmanaged=true ([#2494](https://github.com/kontena/kontena/pull/2494))
* Add configurable stop timeout for services ([#2033](https://github.com/kontena/kontena/pull/2033))
* Read-only container instances ([#2550](https://github.com/kontena/kontena/pull/2550))
* Fix usage of node IDs in CLI, server API JSON + docs ([#2483](https://github.com/kontena/kontena/pull/2483))
* Create HostNode with per-node token for websocket auth ([#2504](https://github.com/kontena/kontena/pull/2504))
* Fix kontena node rm: NameError: undefined local variable or method `node_id` ([#2580](https://github.com/kontena/kontena/pull/2580))
* Build deb package with omnibus ([#2614](https://github.com/kontena/kontena/pull/2614))
* Rewrite CLI container exec websocket client ([#2599](https://github.com/kontena/kontena/pull/2599))
* Remove development deps from CLI Omnibus Gemfile ([#2624](https://github.com/kontena/kontena/pull/2624))
* Fix node token clear to use DELETE /v1/nodes/:id/token ([#2636](https://github.com/kontena/kontena/pull/2636))
* cli: fix Dockerfile gem install needing ruby-dev for websocket-driver ([#2640](https://github.com/kontena/kontena/pull/2640))
* Fix cli omnibus package name to kontena-cli ([#2656](https://github.com/kontena/kontena/pull/2656))
* Add support for soft affinities ([#2540](https://github.com/kontena/kontena/pull/2540))
* Fix unnecessary spinner nesting during master deploy wizard ([#2660](https://github.com/kontena/kontena/pull/2660))
* Change CLI log --tail/follow options to match Docker ([#2046](https://github.com/kontena/kontena/pull/2046))
* Raise cli excon timeout defaults ([#2671](https://github.com/kontena/kontena/pull/2671))
* Fix kontena registry create to use --s3-v4auth by default ([#2673](https://github.com/kontena/kontena/pull/2673))
* Fix nil resource usage error on node show cmd ([#2678](https://github.com/kontena/kontena/pull/2678))
* Add PLATFORM as variable for stack parsing ([#2677](https://github.com/kontena/kontena/pull/2677))
* Fix error message when trying to use nonexistent master ([#2668](https://github.com/kontena/kontena/pull/2668))
* CLI: Error out from init-cloud when master already cloud-enabled ([#2680](https://github.com/kontena/kontena/pull/2680))
* Node scheduling availability ([#2306](https://github.com/kontena/kontena/pull/2306))
* Fix node show specs to include availability attribute ([#2687](https://github.com/kontena/kontena/pull/2687))
* CLI: Exit with error from node ssh --any if no nodes are online ([#2686](https://github.com/kontena/kontena/pull/2686))
* Make stack yml interpolation default ENVs extendable for plugin devs ([#2667](https://github.com/kontena/kontena/pull/2667))
* Refactor plugin manager ([#2434](https://github.com/kontena/kontena/pull/2434))
* CLI: Use the "press any key" dialog from tty-prompt library ([#2666](https://github.com/kontena/kontena/pull/2666))
* cli: bump kontena-websocket-client to 0.1.1 ([#2698](https://github.com/kontena/kontena/pull/2698))
* CLI: Removed the app subcommand, it is now available as a plugin ([#2675](https://github.com/kontena/kontena/pull/2675))
* Make stack logs accept service names as filters ([#2713](https://github.com/kontena/kontena/pull/2713))
* agent: report container exec errors ([#2745](https://github.com/kontena/kontena/pull/2745))
* Add kontena stack deploy --no-wait ([#2758](https://github.com/kontena/kontena/pull/2758))
* Add LE TOS agreement on register command ([#2754](https://github.com/kontena/kontena/pull/2754))
* Service cpus limit ([#2541](https://github.com/kontena/kontena/pull/2541))
* Initial tls-sni support and new api for domain authorizations ([#2732](https://github.com/kontena/kontena/pull/2732))
* Allow stacks to depend on other stacks ([#2707](https://github.com/kontena/kontena/pull/2707))
* New certificate model, API, service YAML ([#2736](https://github.com/kontena/kontena/pull/2736))
* Fix CLI stack source not found error from "can't determine origin" to generic "no such file" ([#2809](https://github.com/kontena/kontena/pull/2809))
* Fix stack upgrade to use --keep-dependencies ([#2808](https://github.com/kontena/kontena/pull/2808))
* Fix stack variables to not write to env by default ([#2802](https://github.com/kontena/kontena/pull/2802))
* Enhanced HostNode status, health ([#2511](https://github.com/kontena/kontena/pull/2511))
* Show certs with service details ([#2826](https://github.com/kontena/kontena/pull/2826))
* Fix interpolation of stack variables declared by `to: env` ([#2822](https://github.com/kontena/kontena/pull/2822))
* Support shm_size ([#2767](https://github.com/kontena/kontena/pull/2767))
* Add cloud plugin to installers ([#2831](https://github.com/kontena/kontena/pull/2831))
* Add --values option to kontena stack show command ([#2409](https://github.com/kontena/kontena/pull/2409))
* Fix exec console size ([#2708](https://github.com/kontena/kontena/pull/2708))
* CLI: Add --values-from-stack option to stack commands for reading values from an installed stack ([#2795](https://github.com/kontena/kontena/pull/2795))
* Fix stack validate command and validity checking when installing ([#2812](https://github.com/kontena/kontena/pull/2812))
* CLI: Add --no-wait option to kontena service deploy ([#2847](https://github.com/kontena/kontena/pull/2847))
* Fix oneshot hooks; Change post_start hooks to run on start; Add pre_start, pre_stop hooks ([#2701](https://github.com/kontena/kontena/pull/2701))
* Add cert delete API and CLI command ([#2850](https://github.com/kontena/kontena/pull/2850))
* Add --dry-run to simulate kontena stack upgrade ([#2823](https://github.com/kontena/kontena/pull/2823))
* List auto-renewable certificates; Migrate existing LE cert secrets to new certificate models ([#2867](https://github.com/kontena/kontena/pull/2867))
* Fix cli node health specs duration off-by-one timing ([#2870](https://github.com/kontena/kontena/pull/2870))
* Remove experimental status from volumes ([#2864](https://github.com/kontena/kontena/pull/2864))
* Fix missing stack and grid variables when running validate with --online flag ([#2886](https://github.com/kontena/kontena/pull/2886))
* Change "new stacks" color to green in stack upgrade report ([#2890](https://github.com/kontena/kontena/pull/2890))
* CLI: Do not output field names in quiet mode when there is no data ([#2876](https://github.com/kontena/kontena/pull/2876))
* Deploy CLI omnibus deb to bintray ([#2658](https://github.com/kontena/kontena/pull/2658))
* Fix CLI omnibus liblzma source ([#2903](https://github.com/kontena/kontena/pull/2903))
* Fix CLI omnibus liblzma source url ([#2907](https://github.com/kontena/kontena/pull/2907))
* Support for stop_signal ([#2918](https://github.com/kontena/kontena/pull/2918))
* Fix CLI output hang after exceptions raised in spinners ([#2906](https://github.com/kontena/kontena/pull/2906))
* CLI: Make volumes ls -q output name instead of grid/name ([#2926](https://github.com/kontena/kontena/pull/2926))

#### Docs

* Fixing typo in LB docs ([#2492](https://github.com/kontena/kontena/pull/2492))
* docs (nodes) Fix dockerd labels without a value ([#2454](https://github.com/kontena/kontena/pull/2454))
* Unify common grid create/update POST/PUT parameters ([#2488](https://github.com/kontena/kontena/pull/2488))
* Automatically determine volume driver version from installed plugins ([#2526](https://github.com/kontena/kontena/pull/2526))
* Update What Is Kontena? documentation ([#2451](https://github.com/kontena/kontena/pull/2451))
* Add configurable stop timeout for services ([#2033](https://github.com/kontena/kontena/pull/2033))
* Run post_start hooks before wait for port ([#2543](https://github.com/kontena/kontena/pull/2543))
* Support basic authentication in auth provider userinfo request ([#2260](https://github.com/kontena/kontena/pull/2260))
* Ephemeral nodes should not get any stateful services ([#2549](https://github.com/kontena/kontena/pull/2549))
* make local gitbook work without GA & Hubspot tokens ([#2586](https://github.com/kontena/kontena/pull/2586))
* Create HostNode with per-node token for websocket auth ([#2504](https://github.com/kontena/kontena/pull/2504))
* Add new user_admin role ([#2577](https://github.com/kontena/kontena/pull/2577))
* Rewrite agent websocket client ([#2560](https://github.com/kontena/kontena/pull/2560))
* Ubuntu kontena-agent: Use /usr/bin/dockerd for compatibility with Docker 1.12 - 17.06 ([#2589](https://github.com/kontena/kontena/pull/2589))
* Configurable agent node ID, labels ([#2590](https://github.com/kontena/kontena/pull/2590))
* Add support for soft affinities ([#2540](https://github.com/kontena/kontena/pull/2540))
* Add v4auth to create registry with s3 driver ([#2242](https://github.com/kontena/kontena/pull/2242))
* Node scheduling availability ([#2306](https://github.com/kontena/kontena/pull/2306))
* Agent: Allow overriding KONTENA_NODE_NAME ([#2693](https://github.com/kontena/kontena/pull/2693))
* CLI: Removed the app subcommand, it is now available as a plugin ([#2675](https://github.com/kontena/kontena/pull/2675))
* Split out docs as a separate repo ([#2752](https://github.com/kontena/kontena/pull/2752))

## [1.3.5](https://github.com/kontena/kontena/releases/tag/v1.3.5) (2017-11-03)

The 1.3.5 release fixes several issues in the 1.3 release, as well as some older issues.

This release also includes a change to how the server estimates container memory utilization when selecting a node with sufficient free memory: instead of looking at the current memory utilization of the oldest service container, the server will now use the peak memory utilization across all service containers for the past hour.

### Fixed issues

* kontena node/labels update does not notify nodes #2746

    This issue can cause new nodes being provisioned within the same `region` to establish weave connections using their public IP, instead of the private IP that nodes should be using within the same region. This affects nodes in AWS VPCs with security groups managed by `kontena aws node create` in particular. Workaround is to restart the `kontena-agent` on the nodes.

    Introduced in version 1.3.0, does not affect 1.2 or earlier.

* Server leaks memory if new containers are constantly created and destroyed #2895

* Continual high CPU usage #2719

    The background service re-scheduling is now more efficient, consuming significantly less CPU while idle.

### Changes

#### Master

* Fix server ContainerInfoMapper memory leak ([#2896](https://github.com/kontena/kontena/pull/2896)) ([#2940](https://github.com/kontena/kontena/pull/2940))
* backport #2747 ([#2941](https://github.com/kontena/kontena/pull/2941))
* Improve scheduler performance ([#2921](https://github.com/kontena/kontena/pull/2921)) ([#2973](https://github.com/kontena/kontena/pull/2973))

## [1.3.4](https://github.com/kontena/kontena/releases/tag/v1.3.4) (2017-07-20)

### Known issues

* Ubuntu kontena-agent package is not compatible with Docker 17.06 #2588

    This has been fixed for the 1.3 releases by marking the Ubuntu packages as incompatible with the newest `docker-ce` 17.06 packages.

    The 1.4 release will support the Docker 17.06 release, but will also bump the minimum Docker version from 1.10 to 1.12.

### Fixed issues

* `kontena grid update` does not notify nodes #2584
* Grid non-admin user can remove other users from grid #2578

### Changes

#### Master

* Fix server grids update notify ([#2585](https://github.com/kontena/kontena/pull/2585))
* Fix grid user remove access check ([#2579](https://github.com/kontena/kontena/pull/2579))
* Fix Ubuntu kontena-server/kontena-agent packages to be incompatible with docker 17.06 ([#2593](https://github.com/kontena/kontena/pull/2593))

#### Agents
* Fix Ubuntu kontena-server/kontena-agent packages to be incompatible with docker 17.06 ([#2593](https://github.com/kontena/kontena/pull/2593))

## [1.3.3](https://github.com/kontena/kontena/releases/tag/v1.3.3) (2017-07-06)

**Master & Agents:**

- Use latest HostNodeStat entry when serializing host node ([#2555](https://github.com/kontena/kontena/pull/2555))
- Run post_start hooks before wait for port ([#2543](https://github.com/kontena/kontena/pull/2543))


## [1.3.2](https://github.com/kontena/kontena/releases/tag/v1.3.2) (2017-06-30)

**Master & Agents:**

- Server: Fix GridServices::Update with multiple names for the same service secret ([#2506](https://github.com/kontena/kontena/pull/2506))
- Fix LE cert authorization mutation to fail gracefully if not yet registered ([#2497](https://github.com/kontena/kontena/pull/2497))
- Fix healtcheck port validation to check port in unix port range ([#2496](https://github.com/kontena/kontena/pull/2496))
- Fix Etcd launcher to tolerate docker errors better ([#2509](https://github.com/kontena/kontena/pull/2509))
- Automatically determine volume driver version from installed plugins ([#2526](https://github.com/kontena/kontena/pull/2526))
- Fix any versioned kontena/lb:* image to resolve as an LB service, not just latest ([#2530](https://github.com/kontena/kontena/pull/2530))
- Fix mongoid last sort ([#2534](https://github.com/kontena/kontena/pull/2534))

**CLI:**

- Only use STDIN.raw for tty-mode execs ([#2499](https://github.com/kontena/kontena/pull/2499))
- Fix cli node list sorting, specs ([#2512](https://github.com/kontena/kontena/pull/2512))

## [1.3.1](https://github.com/kontena/kontena/releases/tag/v1.3.1) (2017-06-16)

**Master & Agents:**

- Allow server port to be set via env ([#2455](https://github.com/kontena/kontena/pull/2455))
- Increase RpcClient timeouts from 2s to 5s ([#2461](https://github.com/kontena/kontena/pull/2461))
- Fix oauth2 api request body www-form decoding ([#2485](https://github.com/kontena/kontena/pull/2485))

**CLI:**

- Fix plugin installation SafeYAML errors ([#2462](https://github.com/kontena/kontena/pull/2462))
- Fix exit code when plugin install fails ([#2471](https://github.com/kontena/kontena/pull/2471))
- Show an initializing node name as (initializing) instead of nil error in node list ([#2478](https://github.com/kontena/kontena/pull/2478))
- Add a "Getting started" banner to main command help ([#2385](https://github.com/kontena/kontena/pull/2385))

**Other:**

- Tests: Upgrade agent test vagrant docker-compose to version 1.13 ([#2463](https://github.com/kontena/kontena/pull/2463))
- Tests: Update test kommando to fix missing bash failures ([#2475](https://github.com/kontena/kontena/pull/2475))
- Tests: Fix container specs to use quiet option and with proper regexp ([#2467](https://github.com/kontena/kontena/pull/2467))
- Tests: bundle update Gemfile.lock with kommando 0.1.2, safe_yaml changes ([#2481](https://github.com/kontena/kontena/pull/2481))
- Docs: Add capped collection size envs ([#2464](https://github.com/kontena/kontena/pull/2464))
- Docs: add nodes to summary ([#2473](https://github.com/kontena/kontena/pull/2473))
- Docs: fix upgrading major.major typo ([#2472](https://github.com/kontena/kontena/pull/2472))
- Master-dev: Bump mongoid pool size ([#2477](https://github.com/kontena/kontena/pull/2477))

## [1.3.0](https://github.com/kontena/kontena/releases/tag/v1.3.0) (2017-06-09)

### Highlights

This release upgrades the used MongoDB driver to a version which supports newer MongoDB release than 3.0. It essentially means that now there's support for using hosted (e.g. Mongo Atlas) services as Kontena Master database. And naturally, the newer mongoid and underlying db driver boosts the stability of the server.

We've also added support for using Kontena CLI to open an interactive terminals into running service instances. This makes debugging and executing any maintenance scripts a lot easier.

All CLI list commands such as `kontena node list` or `kontena service list` now accept `-q` or `--quiet` parameter for outputting only the identifying column of the list, such as node name or container ID. This makes it easier to pipe the output to other commands. For example: `kontena service ls -q|xargs -n1 kontena service show`.

### Breaking changes

CLI trusted-subnet command has been refactored to match same pattern with other commands to use the current grid automatically. If a user has written some scripts that utilize any of these subcommands, after this change they will simply fail due to `ERROR: too many arguments` and not corrupt any data until the extra grid parameter is removed from said scripts.

`kontena service exec` command has changed the meaning of short `-i` option. Now it means `--interactive`, the new option for executing on specific instance is `--instance`. This change is done to comply with `docker exec -it` options which users are accustomed to use tp get interactive terminals into running containers.

### Deprecations

CLI `kontena app ...` commands have been now deprecated in favor of `kontena stack` commands.


**Master & Agents:**

- Fix agent env validation abort, defaults ([#2302](https://github.com/kontena/kontena/pull/2302))
- Refactor agent WeaveHelper to avoid unnecessary sync actor calls ([#2207](https://github.com/kontena/kontena/pull/2207))
- Validate service envs on server, simplify syntax for parsing/validation ([#2315](https://github.com/kontena/kontena/pull/2315))
- Stack stop and restart commands ([#2299](https://github.com/kontena/kontena/pull/2299))
- Fix server stack services sorting ([#1980](https://github.com/kontena/kontena/pull/1980))
- Upgrade to Mongoid 5.2 ([#2257](https://github.com/kontena/kontena/pull/2257))
- Don't crash VolumeManager if volume remove fails ([#2343](https://github.com/kontena/kontena/pull/2343))
- Serialize all pubsub payloads to avoid issues with dotted fields ([#2342](https://github.com/kontena/kontena/pull/2342))
- Improve mutations to return multiple errors for a field ([#2058](https://github.com/kontena/kontena/pull/2058))
- Notify nodes when volumes are removed ([#2352](https://github.com/kontena/kontena/pull/2352))
- Fix server HealthCheckWorker pubsub payload ([#2361](https://github.com/kontena/kontena/pull/2361))
- Wrap server MongoPubsub subscribe payload in a HashWithIndifferentAccess ([#2357](https://github.com/kontena/kontena/pull/2357))
- Do not split www-authenticate header to multiple lines ([#2329](https://github.com/kontena/kontena/pull/2329))
- Increase master authentication logging ([#2367](https://github.com/kontena/kontena/pull/2367))
- Cleanup leftover HostNode methods ([#2326](https://github.com/kontena/kontena/pull/2326))
- Remove unused agent Kontena::Pubsub class ([#2337](https://github.com/kontena/kontena/pull/2337))
- Fix websocket node connection plug, unplug races ([#2144](https://github.com/kontena/kontena/pull/2144))
- Destroy access_token only if not nil ([#2375](https://github.com/kontena/kontena/pull/2375))
- Fix server mutations validations regexps ([#2325](https://github.com/kontena/kontena/pull/2325))
- Add tracking if service embedded docs changes ([#2377](https://github.com/kontena/kontena/pull/2377))
- Update JsonPath gem ([#2382](https://github.com/kontena/kontena/pull/2382))
- Do not send Content-Type in AuthProvider GET requests ([#2386](https://github.com/kontena/kontena/pull/2386))
- Service and container exec interactive tty support ([#2271](https://github.com/kontena/kontena/pull/2271))
- Improve platform identification on the Kontena Cloud ([#2388](https://github.com/kontena/kontena/pull/2388))
- Add tty as separate option in container/service exec ([#2412](https://github.com/kontena/kontena/pull/2412))
- Fix auth api debug message ([#2429](https://github.com/kontena/kontena/pull/2429))
- Terminate ContainerHealthCheckWorker less brutally ([#2440](https://github.com/kontena/kontena/pull/2440))
- Render service links with qualified name ([#2421](https://github.com/kontena/kontena/pull/2421))


**CLI:**

- Activate plugin gem and dependencies before loading the plugin ([#2180](https://github.com/kontena/kontena/pull/2180))
- Remove broken/dead code for cli ssh command parameter handling  ([#2309](https://github.com/kontena/kontena/pull/2309))
- Make trusted-subnet subcommands use the current_grid or --grid ([#2294](https://github.com/kontena/kontena/pull/2294))
- Stack stop and restart commands ([#2299](https://github.com/kontena/kontena/pull/2299))
- Exit with non-zero exit code when commands run other commands that fail  ([#2209](https://github.com/kontena/kontena/pull/2209))
- Replace implementation of "press any key" dialog ([#2052](https://github.com/kontena/kontena/pull/2052))
- Add deprecation flag for app commands ([#2336](https://github.com/kontena/kontena/pull/2336))
- Fix subcommand loading bug when running init-cloud ([#2350](https://github.com/kontena/kontena/pull/2350))
- Fix stack YAML reader exception with invalid port syntax ([#2332](https://github.com/kontena/kontena/pull/2332))
- Remote cloud login ([#2331](https://github.com/kontena/kontena/pull/2331))
- Make all "kontena XX list" commands accept -q (or --quiet) to only output the id column without header ([#2327](https://github.com/kontena/kontena/pull/2327))
- Increase MEM_MAX_LIMITS readability ([#2341](https://github.com/kontena/kontena/pull/2341))
- Allow stack registry read operations without cloud authentication ([#2328](https://github.com/kontena/kontena/pull/2328))
- CLI error and debug logging improvements ([#2263](https://github.com/kontena/kontena/pull/2263))
- Speed up CLI loading by reducing the number of explicitly loaded files ([#2335](https://github.com/kontena/kontena/pull/2335))
- Revert any_key_to_continue implementation ([#2379](https://github.com/kontena/kontena/pull/2379))
- Make kontena master ssh work without server.provider set ([#2380](https://github.com/kontena/kontena/pull/2380))
- Service instance resolver undefined local variable or method  ([#2381](https://github.com/kontena/kontena/pull/2381))
- Finetune header formatting on list commands ([#2397](https://github.com/kontena/kontena/pull/2397))
- Fix completions that got broken in 1.3.0rc ([#2395](https://github.com/kontena/kontena/pull/2395))
- Replace websocket-client-simple with embedded ws client ([#2396](https://github.com/kontena/kontena/pull/2396))
- Add yaml loading to error handling ([#2402](https://github.com/kontena/kontena/pull/2402))
- Fix master join command option forwarding to master login ([#2394](https://github.com/kontena/kontena/pull/2394))
- Fix cloud master update endpoint ([#2422](https://github.com/kontena/kontena/pull/2422))
- Add tty as separate option in container/service exec ([#2412](https://github.com/kontena/kontena/pull/2412))
- Fix typo in service exec ws close ([#2432](https://github.com/kontena/kontena/pull/2432))
- Fix include/extend in the master deploy wizard ([#2405](https://github.com/kontena/kontena/pull/2405))
- Added requires for excon and json to plugin_manager ([#2420](https://github.com/kontena/kontena/pull/2420))
- Fix error in exec commands when master url does not have a trailing slash ([#2424](https://github.com/kontena/kontena/pull/2424))
- Avoid missing constants by using autoload ([#2425](https://github.com/kontena/kontena/pull/2425))
- Add autoload for StringIO ([#2443](https://github.com/kontena/kontena/pull/2443))
- Fix init-cloud call args during deploy wizard ([#2444](https://github.com/kontena/kontena/pull/2444))


**Other:**

- E2E tests: service_link resolver requires kontena stack validate --online ([#2285](https://github.com/kontena/kontena/pull/2285))
- Fix Bearer token header examples in docs ([#2330](https://github.com/kontena/kontena/pull/2330))
- Fix flaky vpn E2E specs ([#2370](https://github.com/kontena/kontena/pull/2370))
- fix broken e2e link spec ([#2363](https://github.com/kontena/kontena/pull/2363))
- Statsd exporting example was missing grid name ([#2389](https://github.com/kontena/kontena/pull/2389))



## [1.2.2](https://github.com/kontena/kontena/releases/tag/v1.2.2) (2017-05-10)

The 1.2.2 release fixes several issues in the 1.2 release, as well as some older issues.

### Fixed issues

#### [1.2.2.rc2](https://github.com/kontena/kontena/releases/tag/v1.2.2.rc2) (2017-05-09)

* GridServiceDeploy can get stuck in pending state if deploy create races with service remove #2275

#### [1.2.2.rc1](https://github.com/kontena/kontena/releases/tag/v1.2.2.rc1) (2017-05-08)
* kontena registry create "ERROR" #2246
* Syntax errors in kontena.yml service environment cause API 500 errors #2238
* CLI: kontena grid update clears out default-affinity #2252
* grid statsd server cannot be cleared once set #2230
* Stopping service does not abort running deploy #2214
* Queued deploys time out after 10s if another deploy is running, leaving them stuck #2213
* Service deploys can get stuck if there are several queued deploys when a service finishes deploying #2212
* Server GridServiceDeployer can run for longer than 5-10 minutes, allowing further deploys to run simultaneously #2215
* Agent: Actor crash-and-restart loop will eat lot of resources #2231
* Agent WeaveWorker starts seeing container events twice after weave restart event #2225
* Server API views should be optimized to pre-fetch referenced objects, avoiding O(N) queries #2234
* Kontena 1.2 fails to re-schedule stateful ha service instance on removed node #2274
* Random strategy moves services constantly #2244
* Random strategy fails to schedule stateful service with existing instances #2254
* Service `*.kontena.local` DNS aliases missing after `kontena grid trusted-subnet` changes #2158

### Changes

#### Packaging
* sign osx pkg properly ([#2255](https://github.com/kontena/kontena/pull/2255))

#### Agent
* Don't crash StatsWorker actor if statsd config fails ([#2262](https://github.com/kontena/kontena/pull/2262))
* Prevent WeaveWorker from doing duplicate subscription for container:event ([#2265](https://github.com/kontena/kontena/pull/2265))
* Fix agent weave restart ([#2278](https://github.com/kontena/kontena/pull/2278))
* Fix flaky WeaveWorker notification spec ([#2282](https://github.com/kontena/kontena/pull/2282))
* Fix agent ServicePodWorker to log complete apply error ([#2292](https://github.com/kontena/kontena/pull/2292))

#### Server
* Fix server deploy queuing ([#2221](https://github.com/kontena/kontena/pull/2221))
* add missing includes to boost query performance ([#2264](https://github.com/kontena/kontena/pull/2264))
* Include grid and service in container log query ([#2266](https://github.com/kontena/kontena/pull/2266))
* Fix random strategy ([#2256](https://github.com/kontena/kontena/pull/2256))
* Add `--no-statsd-server` and `--no-default-affinity` to "kontena grid update" ([#2251](https://github.com/kontena/kontena/pull/2251))
* Fix GridServiceSerializer deploy_opts min_health typo ([#2268](https://github.com/kontena/kontena/pull/2268))
* Fix handling of aborted service deploys ([#2281](https://github.com/kontena/kontena/pull/2281))
* Abort deploy gracefully in exceptional cases ([#2280](https://github.com/kontena/kontena/pull/2280))
* Do not run server workers in specs ([#2284](https://github.com/kontena/kontena/pull/2284))

#### CLI
* Fix registry create command ([#2240](https://github.com/kontena/kontena/pull/2240))
* Make stack environment variable validation fail if array item has no equals sign ([#2241](https://github.com/kontena/kontena/pull/2241))
* Add require for securerandom in after deploy hook ([#2247](https://github.com/kontena/kontena/pull/2247))
* Add `--no-statsd-server` and `--no-default-affinity` to "kontena grid update" ([#2251](https://github.com/kontena/kontena/pull/2251))
* Fix handling of aborted service deploys ([#2281](https://github.com/kontena/kontena/pull/2281))

## [1.2.1](https://github.com/kontena/kontena/releases/tag/v1.2.1) (2017-04-28)

The 1.2.1 release fixes various issues in the 1.2.0 release.

### Fixed issues

#### [1.2.1.rc1](https://github.com/kontena/kontena/releases/tag/v1.2.1.rc1) (2017-04-27)
* Stack upgrade variable defaulting from master broke in 1.2.0 #2216
* Service volume mounts with :ro breaks validation in 1.2.0 #2219
* CLI: stack reader explodes on an empty stack file: `NoMethodError : undefined method ''[]' for false:FalseClass` #2204
* Missing documentation re upgrading path for named volumes #2222
* OSX cli package (omnibus) is missing readline #2194
* Server: GridServiceHealthMonitorJob can pile up deployments #2208

### Known issues

Known regressions in the Kontena 1.2 releases compared to earlier releases.

* Service deploys can get stuck if there are several queued deploys when a service finishes deploying #2212
* Queued deploys time out after 10s if another deploy is running, leaving them stuck #2213
* Stopping service does not abort running deploy #2214

### Changes

No changes from `1.2.1.rc1`.

* Fix 1.2.0 release notes to document volume migration upgrades ([#2223](https://github.com/kontena/kontena/pull/2223))

#### Agent
* Do not send un-managed volume infos to master ([#2189](https://github.com/kontena/kontena/pull/2189))

#### Server
* Fix GridService#deploy_pending? to consider all unfinished deploys as pending ([#2211](https://github.com/kontena/kontena/pull/2211))

#### CLI
* SSL: Give hint about setting certs path ([#2201](https://github.com/kontena/kontena/pull/2201))
* Make kontena_cli_spec spec test what it was supposed to ([#2210](https://github.com/kontena/kontena/pull/2210))
* Fix variable value defaulting from master during stack upgrade ([#2217](https://github.com/kontena/kontena/pull/2217))
* Fix validation of volume definitions with permission flags ([#2220](https://github.com/kontena/kontena/pull/2220))
* Handle empty YAML files in stack commands ([#2206](https://github.com/kontena/kontena/pull/2206))
* Add rb-readline to CLI installer ([#2205](https://github.com/kontena/kontena/pull/2205))

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

* `kontena grid|stack|service events`

    Follow scheduling and deployment related-events across the Kontena master and node agents.

* `kontena stack install|upgrade|build|validate --values-to --values-from`

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

* Stack upgrade / Service update will not re-deploy service on removal of embedded objects ([#2109](https://github.com/kontena/kontena/pull/2109))

    Removing hooks, links, secrets or volumes from a stack service will not re-deploy the service containers after a `kontena stack upgrade`. Use `kontena service deploy --force` to update the service container configuration.

### Fixed issues

#### [1.2.0.rc1](https://github.com/kontena/kontena/releases/tag/v1.2.0.rc1) (2017-04-07)

* Inconistent `master_admin` access checks ([#1442](https://github.com/kontena/kontena/pull/1442))
* Enable us to pipe service(/cluster?) logs to ELK Stack for example ([#1719](https://github.com/kontena/kontena/pull/1719))
* Agent websocket client connect errors are too vauge ([#1749](https://github.com/kontena/kontena/pull/1749))
* stack install && upgrade to have --values-to ([#1789](https://github.com/kontena/kontena/pull/1789))
* Constant GridServiceDeployer messages for 'daemon' services ([#1862](https://github.com/kontena/kontena/pull/1862))
* Stack deploy hangs in "Waiting for deployment to start" if the deployed service is in restart loop ([#1866](https://github.com/kontena/kontena/pull/1866))
* ServiceBalancerJob loop on daemon services with affinity filter ([#1895](https://github.com/kontena/kontena/pull/1895))
* can not remove "partially_running" stack ([#1928](https://github.com/kontena/kontena/pull/1928))
* Google OAuth 2.0 needs redirect URI to get an access token ([#2015](https://github.com/kontena/kontena/pull/2015))
* Stack vault resolver shows errors ([#2059](https://github.com/kontena/kontena/pull/2059))
* Secret update triggers update of linked service even value does not change ([#2094](https://github.com/kontena/kontena/pull/2094))

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

* Improve how agent rpc server handles requests ([#1607](https://github.com/kontena/kontena/pull/1607))
* more e2e specs ([#1830](https://github.com/kontena/kontena/pull/1830))
* Configurable grid subnet, supernet ([#1323](https://github.com/kontena/kontena/pull/1323))
* Refactor all agent communication to msgpack rpc ([#1855](https://github.com/kontena/kontena/pull/1855))
* Run e2e specs with docker-compose inside docker-compose with CoreOS inside Vagrant ([#1878](https://github.com/kontena/kontena/pull/1878))
* Add timestamps to host node and container stats ([#1908](https://github.com/kontena/kontena/pull/1908))
* Test: Skip compose build, bind-mount /app instead ([#1881](https://github.com/kontena/kontena/pull/1881))
* Remove unnecessary spec_helper requires in tests ([#1932](https://github.com/kontena/kontena/pull/1932))
* Fix ubuntu packages to also support docker-{ce,ee}, fix docker-engine dependencies ([#1950](https://github.com/kontena/kontena/pull/1950))
* Fix travis Ubuntu package deployment to bintray ([#1953](https://github.com/kontena/kontena/pull/1953))
* Fluentd log forwarder ([#1860](https://github.com/kontena/kontena/pull/1860))
* Fix querying of service logs by instance number ([#1874](https://github.com/kontena/kontena/pull/1874))
* Fix Ubuntu xenial package install to not override prompted debconf values with empty values from the default config file ([#1975](https://github.com/kontena/kontena/pull/1975))
* Refactor agent to pull services desired state from the master ([#1873](https://github.com/kontena/kontena/pull/1873))
* Change 2.4.0 to 2.4.1 in travis ([#2017](https://github.com/kontena/kontena/pull/2017))
* Store docker engine plugin information ([#2022](https://github.com/kontena/kontena/pull/2022))
* Volumes api ([#1849](https://github.com/kontena/kontena/pull/1849))
* Metrics API > Services and Containers ([#1995](https://github.com/kontena/kontena/pull/1995))
* Adding CPU to node usage.  Adding more memory stats to metrics API responses.  Adding more unit tests, updating docs. ([#2035](https://github.com/kontena/kontena/pull/2035))
* Volume instance scheduling ([#2020](https://github.com/kontena/kontena/pull/2020))
* Fix nil backtraces in rpc errors ([#1998](https://github.com/kontena/kontena/pull/1998))
* Service instance deploy state, errors ([#2034](https://github.com/kontena/kontena/pull/2034))
* WaitHelper threshold for logging ([#2072](https://github.com/kontena/kontena/pull/2072))
* Grid/stack/service event logs ([#2028](https://github.com/kontena/kontena/pull/2028))
* Volume show command & API ([#2099](https://github.com/kontena/kontena/pull/2099))
* Service instances api & related cli enhancements ([#2101](https://github.com/kontena/kontena/pull/2101))
* Do not log entire yield value from wait_helper ([#2124](https://github.com/kontena/kontena/pull/2124))
* fix e2e service start/stop tests ([#2130](https://github.com/kontena/kontena/pull/2130))
* Improve websocket timeouts and node connection open/close logging ([#2142](https://github.com/kontena/kontena/pull/2142))

#### Docs
* Docs: link env variables reference to summary ([#1912](https://github.com/kontena/kontena/pull/1912))
* Updating development.md guide to include step to delete master nodes from local cli config file ([#1909](https://github.com/kontena/kontena/pull/1909))
* docs: fix upgrading section links ([#1941](https://github.com/kontena/kontena/pull/1941))
* docs (lb) Example on how to include cert intermediates. ([#1939](https://github.com/kontena/kontena/pull/1939))
* Volume related api docs ([#2075](https://github.com/kontena/kontena/pull/2075))
* Docs for volumes ([#2049](https://github.com/kontena/kontena/pull/2049))
* kontena.yml reference improvements ([#2179](https://github.com/kontena/kontena/pull/2179))
* Mention that re-scheduling happens only if service is stateless ([#2178](https://github.com/kontena/kontena/pull/2178))
* docs: service rescheduling after node removal ([#2182](https://github.com/kontena/kontena/pull/2182))

#### Agent
* Agent: Upgrade to faye-websocket 0.10.7 with connection error reasons, close timeouts ([#1757](https://github.com/kontena/kontena/pull/1757))
* Agent: Update weave to 1.9.3 ([#1922](https://github.com/kontena/kontena/pull/1922))
* Fix Agent state_in_sync for stopped containers ([#2023](https://github.com/kontena/kontena/pull/2023))
* Bump IPAM to version 0.2.2 ([#2030](https://github.com/kontena/kontena/pull/2030))
* Refactor agent to use Observable node info ([#2011](https://github.com/kontena/kontena/pull/2011))
* Agent observable fixes ([#2042](https://github.com/kontena/kontena/pull/2042))
* Fix pod manager to populate service name from docker containers ([#2064](https://github.com/kontena/kontena/pull/2064))
* Send both legacy & new driver information from a node ([#2061](https://github.com/kontena/kontena/pull/2061))
* Mount cAdvisor volumes with rshared ([#2005](https://github.com/kontena/kontena/pull/2005))
* Improve agent RPC request error handling ([#2008](https://github.com/kontena/kontena/pull/2008))
* Fix observable spec races ([#2106](https://github.com/kontena/kontena/pull/2106))
* Throttle agent logs streams if queue is full ([#2111](https://github.com/kontena/kontena/pull/2111))
* Fix agent to raise on service container start, stop, restart errors ([#2138](https://github.com/kontena/kontena/pull/2138))
* Check volume driver match when ensuring volume existence ([#2135](https://github.com/kontena/kontena/pull/2135))
* Improve agent resource usage ([#2143](https://github.com/kontena/kontena/pull/2143))
* Reduce agent info logging ([#2155](https://github.com/kontena/kontena/pull/2155))
* Fix agent WeaveWorker to not start until Weave has started ([#2153](https://github.com/kontena/kontena/pull/2153))
* ContainerInfoWorker fixes ([#2147](https://github.com/kontena/kontena/pull/2147))
* Refactor node stats to NodeStatsWorker ([#2166](https://github.com/kontena/kontena/pull/2166))
* Remove unused ContainerStarterWorker ([#2181](https://github.com/kontena/kontena/pull/2181))
* Don't crash ImagePullWorker if pull fails ([#2172](https://github.com/kontena/kontena/pull/2172))
* Fixing nice stats collection typo bug ([#2190](https://github.com/kontena/kontena/pull/2190))
* Check that image is up-to-date in ServicePodWorker ([#2177](https://github.com/kontena/kontena/pull/2177))
* trigger image pull only if deploy_rev changes ([#2198](https://github.com/kontena/kontena/pull/2198))

#### Server
* Display server version on master container startup ([#1839](https://github.com/kontena/kontena/pull/1839))
* Stack deploy command spec was sleeping ([#1746](https://github.com/kontena/kontena/pull/1746))
* Fix master auth config race condition issues ([#1921](https://github.com/kontena/kontena/pull/1921))
* Fixing node_id issue in server node_handler_spec. ([#1944](https://github.com/kontena/kontena/pull/1944))
* Fix grid update specs for --log-forwarder fluentd ([#1971](https://github.com/kontena/kontena/pull/1971))
* Harmonize grid access checks ([#1970](https://github.com/kontena/kontena/pull/1970))
* Fix error in #stop_current_instance if host_node is nil ([#2007](https://github.com/kontena/kontena/pull/2007))
* Save host_node_id in CreateGridServiceInstance migration ([#2006](https://github.com/kontena/kontena/pull/2006))
* Replace server timeout { sleep until ... } loops with non-interrupting wait_until { ... } loops (#1987, #2010)
* Send redirect_uri in authorization_code request as required by some providers ([#2016](https://github.com/kontena/kontena/pull/2016))
* Fix missing server Rpc::GridSerializer fields ([#2014](https://github.com/kontena/kontena/pull/2014))
* Trace and fix server sharing of Moped::Session connections between threads ([#1965](https://github.com/kontena/kontena/pull/1965))
* Send events to Kontena Cloud in real time ([#1906](https://github.com/kontena/kontena/pull/1906))
* don't count volume containers into totals in aggregation ([#2031](https://github.com/kontena/kontena/pull/2031))
* Fix grid metrics CPU calculation ([#2044](https://github.com/kontena/kontena/pull/2044))
* remove duplicate json-serializer from Gemfile ([#2055](https://github.com/kontena/kontena/pull/2055))
* Improve RpcServer performance ([#2050](https://github.com/kontena/kontena/pull/2050))
* Improve server stack mutatations to return errors for multiple services ([#1976](https://github.com/kontena/kontena/pull/1976))
* Remove volume creation as part of stacks ([#2070](https://github.com/kontena/kontena/pull/2070))
* Fix possible thread leaks in WebsocketBackend ([#2056](https://github.com/kontena/kontena/pull/2056))
* Refactor stacks api to always require extenal name for a volume ([#2077](https://github.com/kontena/kontena/pull/2077))
* Add missing DuplicateMigrationVersionError ([#2066](https://github.com/kontena/kontena/pull/2066))
* Do nothing if secret value does not change on update ([#2095](https://github.com/kontena/kontena/pull/2095))
* Only cleanup nodes labeled as ephemeral ([#2084](https://github.com/kontena/kontena/pull/2084))
* Fix service update changes detection ([#2097](https://github.com/kontena/kontena/pull/2097))
* Fix scheduler to raise better error if given empty nodes ([#2107](https://github.com/kontena/kontena/pull/2107))
* Fix migration timeout issues ([#2123](https://github.com/kontena/kontena/pull/2123))
* do not reschedule stateful service automatically ([#2137](https://github.com/kontena/kontena/pull/2137))
* Fix service, stack deploy errors ([#2132](https://github.com/kontena/kontena/pull/2132))
* Server WebsocketBackend EventMachine watchdog ([#2139](https://github.com/kontena/kontena/pull/2139))
* migration service instance also from volume containers ([#2129](https://github.com/kontena/kontena/pull/2129))
* Fix stack deploy service removal ([#2128](https://github.com/kontena/kontena/pull/2128))
* Bring scheduler node offline grace period back ([#2141](https://github.com/kontena/kontena/pull/2141))
* Include CPU in resource usage json ([#2151](https://github.com/kontena/kontena/pull/2151))
* Add service pod caching on Rpc::NodeServicePodHandler ([#2146](https://github.com/kontena/kontena/pull/2146))
* Fix scheduler to notice if instance node was removed ([#2152](https://github.com/kontena/kontena/pull/2152))
* Fix server NodePlugger.plugin logging of new nodes without names ([#2156](https://github.com/kontena/kontena/pull/2156))
* Fix rake tasks to require celluloid/current ([#2169](https://github.com/kontena/kontena/pull/2169))
* Return container stats only from running instances ([#2160](https://github.com/kontena/kontena/pull/2160))
* remove bundler from bin/kontena-console ([#2170](https://github.com/kontena/kontena/pull/2170))
* Fix Service Metrics CPU ([#2162](https://github.com/kontena/kontena/pull/2162))
* Raise puma worker boot timeout & remove background threads ([#2187](https://github.com/kontena/kontena/pull/2187))

#### CLI
* Upgrade to tty-prompt 0.11 with improved windows support ([#1901](https://github.com/kontena/kontena/pull/1901))
* Fix cli specs to use an explicit client instance_double ([#1747](https://github.com/kontena/kontena/pull/1747))
* Modifications to simplify kontena-cli homebrew formula ([#1889](https://github.com/kontena/kontena/pull/1889))
* CLI: Fix stacks YAML reader handling of undefined variables ([#1884](https://github.com/kontena/kontena/pull/1884))
* kontena node ssh --any: connect to first connected node ([#1359](https://github.com/kontena/kontena/pull/1359))
* Speed up CLI launching by lazy-loading subcommands ([#1093](https://github.com/kontena/kontena/pull/1093))
* Fixing paths for nested sub commands in calls to load_subcommand. ([#1934](https://github.com/kontena/kontena/pull/1934))
* Send file:// as registry url to allow backwards compatibility with pre v1.1.2 masters ([#1930](https://github.com/kontena/kontena/pull/1930))
* Require --force or confirmation when upgrading to a different stack ([#1940](https://github.com/kontena/kontena/pull/1940))
* Fix omnibus osx wrapper args passing ([#1967](https://github.com/kontena/kontena/pull/1967))
* Fix CLI to output API errors to STDERR ([#1963](https://github.com/kontena/kontena/pull/1963))
* Upgrade opto to 1.8.4 ([#1935](https://github.com/kontena/kontena/pull/1935))
* Validate hook names in kontena.yml ([#2019](https://github.com/kontena/kontena/pull/2019))
* Add --values-to from stack validate to the rest of the stack subcommands ([#1985](https://github.com/kontena/kontena/pull/1985))
* Stack yaml volume mapping parser and validation support ([#1957](https://github.com/kontena/kontena/pull/1957))
* Validate volumes before stack gets created or updated ([#2043](https://github.com/kontena/kontena/pull/2043))
* Deprecate master users subcommand in favor of master user ([#1984](https://github.com/kontena/kontena/pull/1984))
* CLI exception output normalization ([#2057](https://github.com/kontena/kontena/pull/2057))
* Make stack validate not connect to master unless asked ([#2060](https://github.com/kontena/kontena/pull/2060))
* cli: fix node ssh command API URLs ([#2078](https://github.com/kontena/kontena/pull/2078))
* Invite and invite hook were using the deprecated "master users" ([#1984](https://github.com/kontena/kontena/pull/1984)) ([#2085](https://github.com/kontena/kontena/pull/2085))
* require force or confirmation to remove a volume ([#2093](https://github.com/kontena/kontena/pull/2093))
* Refuse to remove an online node ([#2086](https://github.com/kontena/kontena/pull/2086))
* Fix cli master logout module definition ([#2104](https://github.com/kontena/kontena/pull/2104))
* Fix CLI stack logs missing requires, spec ([#2103](https://github.com/kontena/kontena/pull/2103))
* Added prompt to commands that wait for input from STDIN ([#2045](https://github.com/kontena/kontena/pull/2045))
* bump hash-validator to 0.7.1 which fixes the 'external: false' validation ([#2105](https://github.com/kontena/kontena/pull/2105))
* Make stack variable yes/no prompts honor default value ([#2053](https://github.com/kontena/kontena/pull/2053))
* CLI: mark volumes commands as experimental ([#2108](https://github.com/kontena/kontena/pull/2108))
* In cli login command, finish method was returning nil, which caused browser web flow prompt even when a valid token was passed in ([#2145](https://github.com/kontena/kontena/pull/2145))
* Use tty-table for volume ls ([#2136](https://github.com/kontena/kontena/pull/2136))
* Reduce already initialized constant warnings in api client ([#2140](https://github.com/kontena/kontena/pull/2140))
* "kontena complete --subcommand-tree" prints out the full command tree for tests ([#2102](https://github.com/kontena/kontena/pull/2102))
* CLI logo now says "cli" ([#2167](https://github.com/kontena/kontena/pull/2167))
* Warn, don't exit, when a plugin fails to load ([#2184](https://github.com/kontena/kontena/pull/2184))
* Validate volume declaration on cli only if named volumes used ([#2193](https://github.com/kontena/kontena/pull/2193))
* Stack deploy error reporting ([#2199](https://github.com/kontena/kontena/pull/2199))

## [1.1.2](https://github.com/kontena/kontena/releases/tag/v1.1.2) (2017-02-24)

**Master & Agents:**

- Fix stack service link validation errors ([#1876](https://github.com/kontena/kontena/pull/1876))
- Do not start health check if no protocol specified ([#1863](https://github.com/kontena/kontena/pull/1863))
- Do not filter out a node that already has the service instance when replacing a container ([#1823](https://github.com/kontena/kontena/pull/1823))
- Ubuntu xenial packaging dpkg-reconfigure support ([#1754](https://github.com/kontena/kontena/pull/1754))
- Fix stack service reverse-dependency sorting on links when removing ([#1887](https://github.com/kontena/kontena/pull/1887))
- Fix clearing health check attributes on stack upgrade ([#1837](https://github.com/kontena/kontena/pull/1837))
- Registry url was not saved correctly in stack metadata ([#1870](https://github.com/kontena/kontena/pull/1870))

**CLI:**

- Fix stack service_link resolver default when value optional ([#1891](https://github.com/kontena/kontena/pull/1891))
- Update year to 2017 in CLI logo ([#1840](https://github.com/kontena/kontena/pull/1840))
- Avoid leaking CLI auth codes to cloud in referer header ([#1896](https://github.com/kontena/kontena/pull/1896))

**Other:**

- Docs: fix volumes_from examples and syntax ([#1872](https://github.com/kontena/kontena/pull/1872))
- Dev: Docker compose based local e2e test env ([#1838](https://github.com/kontena/kontena/pull/1838))

## [1.1.1](https://github.com/kontena/kontena/releases/tag/v1.1.1) (2017-02-08)

**Master & Agents:**

- Remove volume containers when removing nodes ([#1805](https://github.com/kontena/kontena/pull/1805))
- Document master HA setup ([#1721](https://github.com/kontena/kontena/pull/1721))
- Allow to clear deploy options after stack install ([#1698](https://github.com/kontena/kontena/pull/1698))

**CLI:**

- Fix service link/unlink errors ([#1814](https://github.com/kontena/kontena/pull/1814))
- Fix plugin cleanup and run it only when plugins are upgraded ([#1813](https://github.com/kontena/kontena/pull/1813))
- Exit with error when piping to/from a command that requires --force and it's not set ([#1804](https://github.com/kontena/kontena/pull/1804))
- Simple menus were not enabled on windows by default as intended in 1.1.0 ([#1802](https://github.com/kontena/kontena/pull/1802))
- Fix for stack variable prompt asking the same question multiple times when no value given ([#1801](https://github.com/kontena/kontena/pull/1801))
- Fix stack vault ssl certificate selection and service link prompts not using given default values ([#1800](https://github.com/kontena/kontena/pull/1800))
- Allow "echo: false" in stack string variables for prompting passwords ([#1796](https://github.com/kontena/kontena/pull/1796))
- Fix stack conditionals short syntax for booleans ([#1795](https://github.com/kontena/kontena/pull/1795))
- Invite self and add the created user as master_admin during 'kontena master init-cloud' ([#1735](https://github.com/kontena/kontena/pull/1735))
- Fix the new --debug flag breaking DEBUG=api full body inspection ([#1821](https://github.com/kontena/kontena/pull/1821))

## [1.1.0](https://github.com/kontena/kontena/releases/tag/v1.1.0) (2017-02-03)

**Master & Agents:**

- Initialize container_seconds properly ([#1764](https://github.com/kontena/kontena/pull/1764))
- Fix service volume update ([#1742](https://github.com/kontena/kontena/pull/1742))
- Set puma workers based on available CPU cores ([#1683](https://github.com/kontena/kontena/pull/1683))
- Switch to use Alpine 3.5 ([#1621](https://github.com/kontena/kontena/pull/1621))
- Add container hours telemetry data ([#1589](https://github.com/kontena/kontena/pull/1589))
- Validate that secrets exist during service create and update ([#1570](https://github.com/kontena/kontena/pull/1570))
- Set grid default affinity ([#1564](https://github.com/kontena/kontena/pull/1564))
- Update Weave Net to 1.8.2 ([#1562](https://github.com/kontena/kontena/pull/1562))
- Changed log level of some messages to debug level in agent ([#1519](https://github.com/kontena/kontena/pull/1519))
- Better deployment errors for "Cannot find applicable node for service instance ..." ([#1512](https://github.com/kontena/kontena/pull/1512))
- Fix service container names to drop null- prefix, and use stack.service-N ([#1494](https://github.com/kontena/kontena/pull/1494))
- Say role not found instead of role can not be nil in role add ([#1458](https://github.com/kontena/kontena/pull/1458))
- Added kontena-console command to master for debugging ([#903](https://github.com/kontena/kontena/pull/903))
- Stop container health check also on kill event ([#1699](https://github.com/kontena/kontena/pull/1699))
- Update image registry to 2.6.0 [enhancement] #1704

**CLI:**

- Remove deprecated commands and options ([#1759](https://github.com/kontena/kontena/pull/1759))
- Stack service link (prompt) resolver ([#1756](https://github.com/kontena/kontena/pull/1756))
- Read variable defaults from master when running stack upgrade (#1662 + #1751)
- Stacks can now be installed/upgraded/validated from files, registry or URLs (#1748 #1736)
- Vault ssl cert resolver for stacks ([#1745](https://github.com/kontena/kontena/pull/1745))
- Improve service stack revision visibility ([#1744](https://github.com/kontena/kontena/pull/1744))
- One step master --remote login ([#1739](https://github.com/kontena/kontena/pull/1739))
- Detect if environment supports running a graphical browser ([#1738](https://github.com/kontena/kontena/pull/1738))
- Deploy stack by default on install/upgrade ([#1737](https://github.com/kontena/kontena/pull/1737))
- Support liquid templating language in stack YAMLs (#1560 #1734)
- Better error message when vault key nil/empty in vault resolver ([#1728](https://github.com/kontena/kontena/pull/1728))
- Add kontena service exec command ([#1726](https://github.com/kontena/kontena/pull/1726))
- Switch cli docker image to use root user ([#1717](https://github.com/kontena/kontena/pull/1717))
- Show origin of installed stack ([#1711](https://github.com/kontena/kontena/pull/1711))
- Improve stack deploy progress output ([#1710](https://github.com/kontena/kontena/pull/1710))
- Make --force more predictable in master rm ([#1703](https://github.com/kontena/kontena/pull/1703))
- Use the master url to build the redirect uri in init-cloud ([#1701](https://github.com/kontena/kontena/pull/1701))
- Rescue from broken pipe ([#1684](https://github.com/kontena/kontena/pull/1684))
- Update spinner message while spinning ([#1679](https://github.com/kontena/kontena/pull/1679))
- Stack service_instances resolver ([#1678](https://github.com/kontena/kontena/pull/1678))
- Show etcd health status ([#1677](https://github.com/kontena/kontena/pull/1677))
- Set master config server.provider during deploy ([#1675](https://github.com/kontena/kontena/pull/1675))
- Optionally use sudo when running docker build/push ([#1673](https://github.com/kontena/kontena/pull/1673))
- Show instance name in service stats ([#1669](https://github.com/kontena/kontena/pull/1669))
- Vault import/export ([#1655](https://github.com/kontena/kontena/pull/1655))
- Master/CLI version difference warning ([#1636](https://github.com/kontena/kontena/pull/1636))
- Add kontena vault import/export commands ([#1634](https://github.com/kontena/kontena/pull/1634))
- Install plugins under $HOME/.kontena/gems and without shell exec ([#1628](https://github.com/kontena/kontena/pull/1628))
- Improve interactive prompts on Windows ([#1585](https://github.com/kontena/kontena/pull/1585))
- Move debug output to STDERR ([#1543](https://github.com/kontena/kontena/pull/1543))
- Add kontena node/grid health commands ([#1468](https://github.com/kontena/kontena/pull/1468))
- Custom instrumentor for debugging http client requests when DEBUG=true ([#1436](https://github.com/kontena/kontena/pull/1436))
- Add kontena --version and global --debug ([#1291](https://github.com/kontena/kontena/pull/1291))
- Enable sending commands to hosts via kontena master/node ssh ([#1205](https://github.com/kontena/kontena/pull/1205))
- OSX CLI installer and automated build ([#1112](https://github.com/kontena/kontena/pull/1112))
- Display agent version in node list ([#996](https://github.com/kontena/kontena/pull/996))

## [1.0.6](https://github.com/kontena/kontena/releases/tag/v1.0.6) (2017-01-18)

**Master & Agents:**

- agent: fix cAdvisor stats to ignore systemd Docker container mount cgroups ([#1657](https://github.com/kontena/kontena/pull/1657))

## [1.0.5](https://github.com/kontena/kontena/releases/tag/v1.0.5) (2017-01-13)

**Master & Agents:**

- fix loadbalancer link removal ([#1623](https://github.com/kontena/kontena/pull/1623))
- disable cAdvisor disk metrics & give lower cpu priority ([#1629](https://github.com/kontena/kontena/pull/1629))
- return 404 if stack not found ([#1613](https://github.com/kontena/kontena/pull/1613))
- fix EventMachine to abort on exceptions ([#1626](https://github.com/kontena/kontena/pull/1626))

**CLI:**

- fix kontena grid cloud-config network units ([#1619](https://github.com/kontena/kontena/pull/1619))

## [1.0.4](https://github.com/kontena/kontena/releases/tag/v1.0.4) (2017-01-04)

**Master & Agents:**

- Send labels with the initial ws connection headers ([#1597](https://github.com/kontena/kontena/pull/1597))
- Fix WebsocketClient reconnect ([#1602](https://github.com/kontena/kontena/pull/1602))


**CLI:**
- Calm down service status polling interval on service delete ([#1596](https://github.com/kontena/kontena/pull/1596))
- Tell why plugin install failed ([#1510](https://github.com/kontena/kontena/pull/1510))

**Loadbalancer:**

- Allow to set custom SSL ciphers ([#1591](https://github.com/kontena/kontena/pull/1591))
- Add custom LB level settings ([#1586](https://github.com/kontena/kontena/pull/1586))


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

- Fix possible race condition in GridServiceScheduler ([#1532](https://github.com/kontena/kontena/pull/1532))
- Fix ServiceBalancer greediness ([#1522](https://github.com/kontena/kontena/pull/1522))
- Fix StackDeploy success state ([#1509](https://github.com/kontena/kontena/pull/1509))
- Boot em&celluloid with initialisers ([#1503](https://github.com/kontena/kontena/pull/1503))
- Fix binding same port on multi IPs ([#1490](https://github.com/kontena/kontena/pull/1490))
- Fix service show DNS ([#1487](https://github.com/kontena/kontena/pull/1487))
- Garbage collect orphan service containers ([#1483](https://github.com/kontena/kontena/pull/1483))
- Deploy stack service one-by-one ([#1482](https://github.com/kontena/kontena/pull/1482))
- Stack-warare loadbalancer ([#1481](https://github.com/kontena/kontena/pull/1481))
- Resolve volumes-from correctly with < 1.0.0 created services ([#1455](https://github.com/kontena/kontena/pull/1455))


**CLI:**

- - Fix service containers command ([#1514](https://github.com/kontena/kontena/pull/1514))
- Use —name when parsing stacks ([#1505](https://github.com/kontena/kontena/pull/1505))
- Fix auth token refreshing ([#1479](https://github.com/kontena/kontena/pull/1479))
- Set GRID and STACK variables for stack files ([#1475](https://github.com/kontena/kontena/pull/1475))



## [1.0.0](https://github.com/kontena/kontena/releases/tag/v1.0.0) (2016-11-29)

**Master & Agents:**

- improve stacks functionality (#864, #1339, #1331, #1338, #1333, #1345, #1347, #1356, #1362, #1358, #1366, #1368, #1372, #1384, #1385, #1386, #1390, #1393, #1378, #1409, #1415, #1425, #1434, #1439)
- improved network / ipam handling (#955, #1274, #1300, #1324, #1322, #1326, #1332, #1336, #1344, #1380, #1379, #1391, #1392, #1398)
- cloud integration (#1340, #1389, #1399, #1408, #1407, #1419)
- rest api docs ([#1406](https://github.com/kontena/kontena/pull/1406))
- refactor secrets api endpoints to match overall naming ([#1405](https://github.com/kontena/kontena/pull/1405))
- refactor containers api endpoint (#1363, #1426)
- refactor nodes api endpoints (#1427, #1441, #1445, #1444, #1447)
- rename services api container_count attribute to instances ([#1404](https://github.com/kontena/kontena/pull/1404))
- fix WaitHelper timeout ([#1361](https://github.com/kontena/kontena/pull/1361))
- do not restart already stopped service instances ([#1355](https://github.com/kontena/kontena/pull/1355))
- make ContainerLogWorker safer ([#1350](https://github.com/kontena/kontena/pull/1350))
- add health status actions on agent and master ([#1115](https://github.com/kontena/kontena/pull/1115))
- enhanced deployment tracking (#1348, #1349)
- fix TelemetryJob version compare ([#1346](https://github.com/kontena/kontena/pull/1346))

**CLI:**

- stack registry integration (#1403, #1428, #1433, #1429)
- fix current master selection after master login ([#1381](https://github.com/kontena/kontena/pull/1381))
- stacks parser (#1351, #1417)
- install self-signed cert locally (#1337, #1416)
- refactor login commands and improve coverage ([#1283](https://github.com/kontena/kontena/pull/1283))
- deprecate service force deploy ([#1295](https://github.com/kontena/kontena/pull/1295))
- option to check only cli version ([#1269](https://github.com/kontena/kontena/pull/1269))
- show docker version in node show ([#1255](https://github.com/kontena/kontena/pull/1255))
- add / Rm multiple node labels. Added label list command. ([#1296](https://github.com/kontena/kontena/pull/1296))
- add quiet option to service list command ([#1312](https://github.com/kontena/kontena/pull/1312))
- remove previous version of a plugin on install ([#1313](https://github.com/kontena/kontena/pull/1313))


## [0.16.3](https://github.com/kontena/kontena/releases/tag/v0.16.3) (2016-11-15)

**Master & Agents:**

- fix environment rake task ([#1311](https://github.com/kontena/kontena/pull/1311))
- watch & notify when dead containers are gone ([#1289](https://github.com/kontena/kontena/pull/1289))
- fix external registry validation ([#1310](https://github.com/kontena/kontena/pull/1310))
- return correct error json when service remove fails ([#1302](https://github.com/kontena/kontena/pull/1302))
- log weaveexec errors ([#1286](https://github.com/kontena/kontena/pull/1286))
- fix all requires to use deterministic ordering across different systems ([#1282](https://github.com/kontena/kontena/pull/1282))

## [0.16.2](https://github.com/kontena/kontena/releases/tag/v0.16.2) (2016-11-03)

**Master & Agents:**

- sort initializers while loading, load symmetric-encryption before seed (#1280, #1277)

**CLI:**

- remove use of to_h for ruby 2.0 compatibility (#1267, #1266)
- fix master list command if current master not set ([#1268](https://github.com/kontena/kontena/pull/1268))

## [0.16.1](https://github.com/kontena/kontena/releases/tag/v0.16.1) (2016-10-31)

**Master & Agents:**

- fix Agent IfaceHelper#interface_ip Errno::EADDRNOTAVAIL case ([#1256](https://github.com/kontena/kontena/pull/1256))
- call attach-router if interface ip does not exist ([#1253](https://github.com/kontena/kontena/pull/1253))
- collect stats only for running containers ([#1239](https://github.com/kontena/kontena/pull/1239))
- fix telemetry id ([#1215](https://github.com/kontena/kontena/pull/1215))
- use upsert in config put ([#1221](https://github.com/kontena/kontena/pull/1221))
- create indexes before running config seed ([#1220](https://github.com/kontena/kontena/pull/1220))

**CLI:**

- login no longer raises when SERVER_NAME is null ([#1254](https://github.com/kontena/kontena/pull/1254))
- fix master provider save to cloud ([#1250](https://github.com/kontena/kontena/pull/1250))
- add script security to openVPN config output ([#1231](https://github.com/kontena/kontena/pull/1231))
- strip possible trailing arguments from remote code display ([#1245](https://github.com/kontena/kontena/pull/1245))
- set cloud master provider and version if provision plugin returns them ([#1180](https://github.com/kontena/kontena/pull/1180))
- don't require current master on first login ([#1242](https://github.com/kontena/kontena/pull/1242))
- better error messages when auth code exchange fails ([#1222](https://github.com/kontena/kontena/pull/1222))
- show username when logging in using auth code ([#1236](https://github.com/kontena/kontena/pull/1236))
- rename duplicate masters during config load ([#1238](https://github.com/kontena/kontena/pull/1238))
- use shellwords to split commands ([#1201](https://github.com/kontena/kontena/pull/1201))
- convert excon timeout variables to integers ([#1227](https://github.com/kontena/kontena/pull/1227))

## [0.16.0](https://github.com/kontena/kontena/releases/tag/v0.16.0) (2016-10-24)

**Master & Agents:**

- OAuth2 support (#1035, #1106, #1108, #1120, #1141)
- optimize service containers api endpoint ([#1195](https://github.com/kontena/kontena/pull/1195))
- don't use force when removing containers ([#1196](https://github.com/kontena/kontena/pull/1196))
- refuse start master if incorrect db version ([#1187](https://github.com/kontena/kontena/pull/1187))
- server telemetry / anon stats (with possibility to opt-out) ([#1179](https://github.com/kontena/kontena/pull/1179))
- improve grid name validation ([#1162](https://github.com/kontena/kontena/pull/1162))
- set default timeout to stop/restart docker calls ([#1167](https://github.com/kontena/kontena/pull/1167))
- restart weave if trusted subnets change ([#1147](https://github.com/kontena/kontena/pull/1147))
- loadbalancer: basic auth support ([#1060](https://github.com/kontena/kontena/pull/1060))
- update Weave Net to 1.7.2 ([#1146](https://github.com/kontena/kontena/pull/1146))
- refactor agent image puller to an actor ([#942](https://github.com/kontena/kontena/pull/942))
- update etcd to 2.3.7 ([#1085](https://github.com/kontena/kontena/pull/1085))
- add instance number to container env ([#1042](https://github.com/kontena/kontena/pull/1042))
- refactor container_logs api endpoint & fix limit behaviour ([#995](https://github.com/kontena/kontena/pull/995))

**CLI:**

- OAuth2 support (#1035, #1082, #1094, #1077, #1097, #1096, #1101, #1103, #1105, #1107, #1133, #1129, #1119, #1080, #1139, #1138, #1176, #1183, #1203, #1207, #1210)
- fallback to master account in config parser ([#1199](https://github.com/kontena/kontena/pull/1199))
- increase client read_timeout to 30s ([#1198](https://github.com/kontena/kontena/pull/1198))
- fix vpn remove error ([#1185](https://github.com/kontena/kontena/pull/1185))
- fix plugin uninstall command ([#1184](https://github.com/kontena/kontena/pull/1184))
- kontena register with a link to signup page ([#1177](https://github.com/kontena/kontena/pull/1177))
- known plugin subcommands will now suggest installing plugin if not installed ([#1175](https://github.com/kontena/kontena/pull/1175))
- remove Content-Type request header if request body is empty ([#1157](https://github.com/kontena/kontena/pull/1157))
- show service instance health ([#1153](https://github.com/kontena/kontena/pull/1153))
- improved request error handling ([#1155](https://github.com/kontena/kontena/pull/1155))
- improved tab-completion script (includes zsh support) ([#1168](https://github.com/kontena/kontena/pull/1168))
- fix `kontena grid env` to use correct token ([#1137](https://github.com/kontena/kontena/pull/1137))
- interactive server deletion from config/cloud ([#1131](https://github.com/kontena/kontena/pull/1131))
- replace dry-validation with hash_validator gem ([#1041](https://github.com/kontena/kontena/pull/1041))
- fix docker build helpers to not use shell syntax ([#1124](https://github.com/kontena/kontena/pull/1124))
- add `kontena container logs` command ([#1001](https://github.com/kontena/kontena/pull/1001))
- show grid token only with `--token` option ([#1109](https://github.com/kontena/kontena/pull/1109))
- show error if installed plugin is too old ([#1116](https://github.com/kontena/kontena/pull/1116))
- allow to set grid token manually in `kontena grid create` ([#1046](https://github.com/kontena/kontena/pull/1046))
- new spinner (#1035, #1083, #1181)
- replace colorize gem with pastel (#1035, #1104, #1114, #1117, #1145)
- give user better feedback when commands are executed ([#1057](https://github.com/kontena/kontena/pull/1057))
- do not send Content-Type header with GET requests ([#1078](https://github.com/kontena/kontena/pull/1078))
- show container exit code ([#927](https://github.com/kontena/kontena/pull/927))
- `app deploy --force` (deprecates `--force-deploy`) ([#969](https://github.com/kontena/kontena/pull/969))

**Packaging:**

- Ubuntu Xenial (16.04) packages (#1150, #1169, #1171, #1173, #1186, #1189)
- allow to use docker 1.12 in Ubuntu packages ([#1169](https://github.com/kontena/kontena/pull/1169))
- ignore vendor files when building docker images ([#1113](https://github.com/kontena/kontena/pull/1113))

## [0.15.5](https://github.com/kontena/kontena/releases/tag/v0.15.5) (2016-10-02)

**CLI:**

- allow to install plugins in cli docker image ([#1055](https://github.com/kontena/kontena/pull/1055))
- handle malformed YAML files in a sane way ([#994](https://github.com/kontena/kontena/pull/994))
- do not clip service env output ([#1036](https://github.com/kontena/kontena/pull/1036))
- handle invalid master name gracefully and improve formatting ([#997](https://github.com/kontena/kontena/pull/997))

## [0.15.4](https://github.com/kontena/kontena/releases/tag/v0.15.4) (2016-09-22)

**CLI:**

- lock dry-gems to exact versions ([#1031](https://github.com/kontena/kontena/pull/1031))

## [0.15.3](https://github.com/kontena/kontena/releases/tag/v0.15.3) (2016-09-20)

**Master & Agents:**

- reconnect event stream always if it stops without error ([#1020](https://github.com/kontena/kontena/pull/1020))
- set service container restart policy to unless-stopped ([#1024](https://github.com/kontena/kontena/pull/1024))

**CLI:**

- lock cli dry-monads version ([#1023](https://github.com/kontena/kontena/pull/1023))

## [0.15.2](https://github.com/kontena/kontena/releases/tag/v0.15.2) (2016-09-10)

**Master & Agents:**

- retry when unknown exception occurs while streaming docker events ([#1005](https://github.com/kontena/kontena/pull/1005))
- fix HostNode#initial_member? error when node_number is nil ([#1000](https://github.com/kontena/kontena/pull/1000))
- fix master boot process race conditions ([#999](https://github.com/kontena/kontena/pull/999))
- always add etcd dns address ([#990](https://github.com/kontena/kontena/pull/990))
- catch service remove timeout error and rollback to prev state ([#989](https://github.com/kontena/kontena/pull/989))
- fix cli log stream buffer mem leak ([#972](https://github.com/kontena/kontena/pull/972))
- fix server log stream thread leak ([#973](https://github.com/kontena/kontena/pull/973))
- use host network in cadvisor container ([#954](https://github.com/kontena/kontena/pull/954))

**CLI:**

- reimplement app logs, with spec tests (#987, #1007)
- allow to use numeric version value in kontena.yml ([#993](https://github.com/kontena/kontena/pull/993))
- do not silently swallow exceptions in logs commands ([#978](https://github.com/kontena/kontena/pull/978))
- remove deprecated provisioning commands from tab-complete ([#980](https://github.com/kontena/kontena/pull/980))
- lock all cli runtime dependencies ([#966](https://github.com/kontena/kontena/pull/966))
- allow to use strings as value of extends option in kontena.yml ([#965](https://github.com/kontena/kontena/pull/965))

## [0.15.1](https://github.com/kontena/kontena/releases/tag/v0.15.1) (2016-09-01)

**Master & Agent:**

- update httpclient  to 2.8.2.3 ([#941](https://github.com/kontena/kontena/pull/941))
- update puma to 3.6.0 ([#945](https://github.com/kontena/kontena/pull/945))
- fix custom cadvisor image volume mappings ([#944](https://github.com/kontena/kontena/pull/944))
- log thread backtraces on TTIN signal ([#938](https://github.com/kontena/kontena/pull/938))
- add user-agent for http healthcheck ([#928](https://github.com/kontena/kontena/pull/928))
- allow agent to shutdown gracefully on SIGTERM (#937, #952)

**CLI:**

- default to fullchain certificate with options for cert only or chain ([#946](https://github.com/kontena/kontena/pull/946))
- freeze dry-configurable version ([#949](https://github.com/kontena/kontena/pull/949))
- fix build arguments normalizing ([#921](https://github.com/kontena/kontena/pull/921))

## [0.15.0](https://github.com/kontena/kontena/releases/tag/v0.15.0) (2016-08-11)

**Master & Agent:**
- use correct cadvisor tag in cadvisor launcher ([#908](https://github.com/kontena/kontena/pull/908))
- do not schedule service if there are pending deploys ([#904](https://github.com/kontena/kontena/pull/904))
- ensure event subscription cleanup after deploy ([#895](https://github.com/kontena/kontena/pull/895))
- improve service list api performance ([#894](https://github.com/kontena/kontena/pull/894))
- update to Alpine 3.4 ([#855](https://github.com/kontena/kontena/pull/855))
- update Weave Net to 1.5.2 (#916, #849)
- cookie load balancer support (session stickyness) ([#841](https://github.com/kontena/kontena/pull/841))
- restart event handling for weave ([#838](https://github.com/kontena/kontena/pull/838))
- index GridServiceDeploy#created_at/started_at fields ([#834](https://github.com/kontena/kontena/pull/834))
- support for Let's Encrypt certificates ([#830](https://github.com/kontena/kontena/pull/830))
- fix race condition in DNS add ([#820](https://github.com/kontena/kontena/pull/820))
- initial health check for remote services (#812, #875, #899, #900)
- fix port definitions to include possibility to set bind ip ([#798](https://github.com/kontena/kontena/pull/798))
- initial stacks api (experimental) (#796, #822, #893)
- support for tagging master and nodes on AWS ([#783](https://github.com/kontena/kontena/pull/783))

**CLI:**
- expand build context to absolute path ([#906](https://github.com/kontena/kontena/pull/906))
- handle env_file on YAML file parsing ([#901](https://github.com/kontena/kontena/pull/901))
- updated_at timestamp to secret listing ([#890](https://github.com/kontena/kontena/pull/890))
- discard empty lines in env_file ([#880](https://github.com/kontena/kontena/pull/880))
- fix deploying registry on azure ([#863](https://github.com/kontena/kontena/pull/863))
- switch coreos to use cgroupfs cgroup driver ([#861](https://github.com/kontena/kontena/pull/861))
- do not require config file for whoami command when env is set ([#858](https://github.com/kontena/kontena/pull/858))
- log tailing retry in EOF case ([#835](https://github.com/kontena/kontena/pull/835))
- update to dry-validation 0.8.0 (#831, #856)
- support for build args in v2 yaml ([#813](https://github.com/kontena/kontena/pull/813))
- container exec command to handle whitespace and strings ([#803](https://github.com/kontena/kontena/pull/803))
- show "not found any build options" only in app build command ([#801](https://github.com/kontena/kontena/pull/801))
- cli plugins (#794, #917)

## [0.14.7](https://github.com/kontena/kontena/releases/tag/v0.14.7) (2016-08-08)

**Master & Agent:**
- update cadvisor to 0.23.2 ([#883](https://github.com/kontena/kontena/pull/883))
- fix possible event stream lockups ([#878](https://github.com/kontena/kontena/pull/878))

## [0.14.6](https://github.com/kontena/kontena/releases/tag/v0.14.6) (2016-07-21)

**Master & Agent:**
- fix agent not reconnecting to master ([#859](https://github.com/kontena/kontena/pull/859))
- do not reschedule service if its already in queue ([#853](https://github.com/kontena/kontena/pull/853))
- fix docker event stream filter params ([#850](https://github.com/kontena/kontena/pull/850))

**CLI:**
- fix deploy interval handling in app yaml parsing ([#821](https://github.com/kontena/kontena/pull/821))

## [0.14.5](https://github.com/kontena/kontena/releases/tag/v0.14.5) (2016-07-09)

**Master & Agent:**

- stream only container events ([#846](https://github.com/kontena/kontena/pull/846))
- always touch last_seen_at on pong ([#845](https://github.com/kontena/kontena/pull/845))
- replug agent on successfull ping ([#842](https://github.com/kontena/kontena/pull/842))
- fix etcd upstream removal ([#836](https://github.com/kontena/kontena/pull/836))

**CLI:**

- do not require Master connection on user verification ([#839](https://github.com/kontena/kontena/pull/839))

## [0.14.4](https://github.com/kontena/kontena/releases/tag/v0.14.4) (2016-07-01)

**CLI:**

- add hard dependency to dry-types gem (#826, #824)

**Other:**

- remove image before tagging, because --force is deprecated ([#833](https://github.com/kontena/kontena/pull/833))

## [0.14.3](https://github.com/kontena/kontena/releases/tag/v0.14.3) (2016-06-16)

**Master & Agent:**
- update excon to 0.49.0 ([#806](https://github.com/kontena/kontena/pull/806))
- enable eventmachine epoll ([#804](https://github.com/kontena/kontena/pull/804))

**CLI:**
- fix aws public ip assign ([#808](https://github.com/kontena/kontena/pull/808))

## [0.14.2](https://github.com/kontena/kontena/releases/tag/v0.14.2) (2016-06-06)

**Master & Agent:**
- do not allow ImageCleanupWorker to remove agent images ([#791](https://github.com/kontena/kontena/pull/791))

**CLI:**
- add s3-v4auth flag for registry create ([#789](https://github.com/kontena/kontena/pull/789))
- improve vpn creation for non-public environments ([#787](https://github.com/kontena/kontena/pull/787))
- generate yaml v2 formatted files on app init command ([#785](https://github.com/kontena/kontena/pull/785))

## [0.14.1](https://github.com/kontena/kontena/releases/tag/v0.14.1) (2016-06-03)

**Master & Agent:**
- fix automatic scale down on too many service instances ([#772](https://github.com/kontena/kontena/pull/772))
- fix nil on cpu usage and refactor stats worker ([#769](https://github.com/kontena/kontena/pull/769))

**CLI:**
- allow to use app name defined in yaml on app config command ([#779](https://github.com/kontena/kontena/pull/779))
- fix kontena app build command error ([#777](https://github.com/kontena/kontena/pull/777))
- enable security group setting for master and nodes in AWS ([#775](https://github.com/kontena/kontena/pull/775))
- verify Upcloud API access ([#774](https://github.com/kontena/kontena/pull/774))
- provider labels for AWS, Azure and DO nodes ([#773](https://github.com/kontena/kontena/pull/773))
- add option in AWS to associate public ip for VPC ([#771](https://github.com/kontena/kontena/pull/771))
- fix log_opts disappearing after service update ([#770](https://github.com/kontena/kontena/pull/770))

## [0.14.0](https://github.com/kontena/kontena/releases/tag/v0.14.0) (2016-05-31)

**Master & Agent:**
- dynamic etcd cluster member replacement functionality ([#719](https://github.com/kontena/kontena/pull/719))
- take availability zones into account in ha scheduling strategy ([#754](https://github.com/kontena/kontena/pull/754))
- notify grid nodes when node information is updated in master ([#752](https://github.com/kontena/kontena/pull/752))
- allow to set agent public/private ip via env ([#697](https://github.com/kontena/kontena/pull/697))
- add rollbar support to master ([#475](https://github.com/kontena/kontena/pull/475))

**CLI:**
- support for Docker Compose YAML V2 format ([#739](https://github.com/kontena/kontena/pull/739))
- upcloud.com provisioning support ([#748](https://github.com/kontena/kontena/pull/748))
- packet.net provisioning support ([#726](https://github.com/kontena/kontena/pull/726))
- improve azure provisioning ([#763](https://github.com/kontena/kontena/pull/763))
- confirm dialog on destructive commands ([#712](https://github.com/kontena/kontena/pull/712))
- allow to define app name in kontena.yml ([#751](https://github.com/kontena/kontena/pull/751))
- new sub-command `app config` ([#749](https://github.com/kontena/kontena/pull/749))
- show agent version in node details ([#736](https://github.com/kontena/kontena/pull/736))
- use region as az in DigitalOcean ([#734](https://github.com/kontena/kontena/pull/734))
- show initial node membership info ([#733](https://github.com/kontena/kontena/pull/733))
- option for upserting secrets ([#711](https://github.com/kontena/kontena/pull/711))
- improved kontena.yml parsing ([#696](https://github.com/kontena/kontena/pull/696))

## [0.13.4](https://github.com/kontena/kontena/releases/tag/v0.13.4) (2016-05-29)

**Master & Agent:**
- allow to deploy service that is already in deploying state ([#743](https://github.com/kontena/kontena/pull/743))

**Packaging:**
- add resolvconf as dependency in ubuntu kontena-agent ([#744](https://github.com/kontena/kontena/pull/744))

## [0.13.3](https://github.com/kontena/kontena/releases/tag/v0.13.3) (2016-05-27)

**Master & Agent:**
- fix possible agent websocket ping_timer race condition ([#731](https://github.com/kontena/kontena/pull/731))
- fix upstream removal to remove only right container instance ([#727](https://github.com/kontena/kontena/pull/727))
- fix service balancer not picking up instances without any deploys ([#725](https://github.com/kontena/kontena/pull/725))
- fix stopped services with open deploys blocking deploy queue ([#724](https://github.com/kontena/kontena/pull/724))

## [0.13.2](https://github.com/kontena/kontena/releases/tag/v0.13.2) (2016-05-24)

**Master & Agent**
- fix how daemon service state is calculated ([#716](https://github.com/kontena/kontena/pull/716))
- fix error in HostNode#region when labels is nil ([#714](https://github.com/kontena/kontena/pull/714))
- fix daemon scheduler node sorting ([#708](https://github.com/kontena/kontena/pull/708))
- fix how service instance running count is checked ([#707](https://github.com/kontena/kontena/pull/707))
- take region into account when resolving peer ip's ([#706](https://github.com/kontena/kontena/pull/706))

**CLI**
- fix service name displaying on app deploy ([#717](https://github.com/kontena/kontena/pull/717))
- fix confusing user invite text ([#715](https://github.com/kontena/kontena/pull/715))
- show debug help only for non Kontena StandardErrors ([#710](https://github.com/kontena/kontena/pull/710))


## [0.13.1](https://github.com/kontena/kontena/releases/tag/v0.13.1) (2016-05-19)

- fix agent websocket hang on close when connection is unstable ([#698](https://github.com/kontena/kontena/pull/698))

## [0.13.0](https://github.com/kontena/kontena/releases/tag/v0.13.0) (2016-05-18)

**Master & Agent**
- grid trusted subnets (weave fast data path) ([#644](https://github.com/kontena/kontena/pull/644))
- scheduler memory filter ([#606](https://github.com/kontena/kontena/pull/606))
- new deploy option: interval ([#657](https://github.com/kontena/kontena/pull/657))
- cadvisor 0.23.0 ([#668](https://github.com/kontena/kontena/pull/668))
- add support for `KONTENA_LB_KEEP_VIRTUAL_PATH` ([#687](https://github.com/kontena/kontena/pull/687))
- improve deploy queue performance ([#690](https://github.com/kontena/kontena/pull/690))
- schedule deploy for related services on vault secret update ([#661](https://github.com/kontena/kontena/pull/661))
- do not overwrite service env variables if value is empty ([#620](https://github.com/kontena/kontena/pull/620))
- return 404 error when (un)assigning nonexisting user to a grid ([#665](https://github.com/kontena/kontena/pull/665))
- remove container_logs full-text indexing ([#677](https://github.com/kontena/kontena/pull/677))
- strip secrets from container env variables ([#679](https://github.com/kontena/kontena/pull/679))
- schedule deploy if service instance has missing overlay_cidr ([#685](https://github.com/kontena/kontena/pull/685))
- remove invalid signal trap ([#689](https://github.com/kontena/kontena/pull/689))

**CLI**
- pre-build hooks ([#588](https://github.com/kontena/kontena/pull/588))
- unify cli subcommands ([#648](https://github.com/kontena/kontena/pull/648))
- improved memory parsing ([#681](https://github.com/kontena/kontena/pull/681))
- add `--mongodb-uri` option to aws master create command ([#676](https://github.com/kontena/kontena/pull/676))
- add `--mongodb-uri` option to digitalocean master create command ([#675](https://github.com/kontena/kontena/pull/675))
- generate self-signed cert for digitalocean master if no cert is provided ([#672](https://github.com/kontena/kontena/pull/672))
- point user account requests directly to auth provider ([#671](https://github.com/kontena/kontena/pull/671))
- fix linked service deletion on `app rm` command ([#653](https://github.com/kontena/kontena/pull/653))
- fix memory parsing errors ([#647](https://github.com/kontena/kontena/pull/647))
- sort node list by node number ([#646](https://github.com/kontena/kontena/pull/646))
- sort service list by updated at ([#645](https://github.com/kontena/kontena/pull/645))
- remove digitalocean floating ip workaround ([#643](https://github.com/kontena/kontena/pull/643))
- sort vault secrets & envs by name ([#641](https://github.com/kontena/kontena/pull/641))
- enable digitalocean & azure master update strategy ([#640](https://github.com/kontena/kontena/pull/640))
- disable vagrant node update stragegy ([#639](https://github.com/kontena/kontena/pull/639))
- load aws coreos amis dynamically from json feed ([#638](https://github.com/kontena/kontena/pull/638))
- tell how to get the full exception when an error occurs ([#635](https://github.com/kontena/kontena/pull/635))
- merge secrets when extending services ([#621](https://github.com/kontena/kontena/pull/621))
- new command `master current` ([#613](https://github.com/kontena/kontena/pull/613))
- show node stats on node details ([#607](https://github.com/kontena/kontena/pull/607))
- save login email to local config ([#589](https://github.com/kontena/kontena/pull/589))

## [0.12.3](https://github.com/kontena/kontena/releases/tag/v0.12.3) (2016-05-06)

- fix node unplugger unclean shutdown ([#662](https://github.com/kontena/kontena/pull/662))

## [0.12.2](https://github.com/kontena/kontena/releases/tag/v0.12.2) (2016-04-26)

- fix too aggressive overlay cidr cleanup ([#626](https://github.com/kontena/kontena/pull/626))
- fix image puller cache invalidation on new deploy using same image tag ([#627](https://github.com/kontena/kontena/pull/627))
- do not ignore containers with name containing weave ([#631](https://github.com/kontena/kontena/pull/631))
- return nil for current_grid if master settings not present in cli ([#632](https://github.com/kontena/kontena/pull/632))

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
