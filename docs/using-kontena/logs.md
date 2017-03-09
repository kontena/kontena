---
title: Logs
---

# Logs

Kontena streams all logs of the services deployed and stores them in Kontena Master for easy access.

There are various methods to access this log information.

- `kontena grid logs` for grid wide logs (all services and Kontena internal components)
- `kontena service logs xyz` for individual service logs
- `kontena stack logs xyz` for stacks service logs

The logs are stored in a capacity-bounded MongoDB collection, which limits the disk space consumed on the master by automatically removing old logs.

## Sending logs for further processing

Often there is a need to further process the logs and gather some relevant statistics and insight what is happening in your services. To ship the logs to some other system there are three different alternatives outlined in below chapters.

### Enable fluentd forwarding

Kontena supports fluentd log shipping that can be configured on each grid. When fluentd forwarding is enabled, all container logs are automatically sent to fluentd for further processing **in addition** of storing them in Kontena Master.

You can enable fluentd forwarding using:
```
kontena grid update --log-forwarder fluentd --log-opt fluentd-address=server[:port] my-grid
```

Each event sent to fluentd is tagged with following notation:
`node.grid.stack.service.instance`

Kontena "system" containers (kontena-agent, ipam-plugin, weave, etc.) will be tagged like:
`node.grid.system.service`

The record itself is a hash with following semantics:
```
{
  log: <log data>,
  type: stdout / stderr
}
```

To disable log forwarding, use:
`kontena grid update --log-forwarder none my-grid`

### Enable container log shipping with Docker.

You can of course use Docker log-driver options when defining services in your stacks. See [log options](../references/kontena-yml.md#logging) for details. Also check Docker log [documentation](https://docs.docker.com/engine/admin/logging/overview/#/supported-logging-drivers) for details on supported drivers and their options.

Or you can define the log drivers on Docker engine level and thus every container will use same log configuration if not otherwise configured.

**Note:** By configuring log forwarding directly on docker or container level makes Kontena not to be able to grab the logs, so they are **not** available on Kontena master.

This is recommended for environments where lots of logs are being generated to avoid Kontena master becoming the bottleneck due to log storing.

### Gather logs from Kontena Master DB

As logs are stored in Kontena Masters database, there is a single point of collection available. The Master database is MongoDB where the logs are stored in capped collection.

To gather logs from master database directly, you need to run the collector somewhere that has access to the master database. Usually the database is not exposed to outside world from the master node, so natural place is to run it alongside with the master.

For example, with fluentd you could use following configuration to get the logs shipped to AWS S3:
```
<source>
  type mongo_tail
  url "#{ENV['MONGODB_URL']}"
  collection container_logs
  tag_key name
  time_key created_at
  id_store_collection container_logs_tail
</source>

<match **>
  @type s3

  aws_key_id "#{ENV['S3_ACCESS_KEY']}"
  aws_sec_key "#{ENV['S3_SECRET_KEY']}"
  s3_bucket "#{ENV['S3_BUCKET']}"
  s3_region "#{ENV['S3_REGION']}"
  buffer_type memory
  buffer_chunk_limit 256m
  buffer_queue_limit 128
  path logs/

  format json
  include_time_key true
  include_tag_key true

  s3_object_key_format %{path}/ts=%{time_slice}/%{index}_json.%{file_extension}
  time_slice_format %Y%m%d-%H
  time_slice_wait 30m
  utc
</match>
```
