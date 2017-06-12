---
title: Stats
---
# Statistics

Kontena collects statistics about running Services with the help of [cAdvisor](https://github.com/google/cadvisor). When an instance of a Service is spun up, Kontena starts to collect statistics and stores them on the Master database. The statistics can be viewed with the Kontena CLI tool:

```
$ kontena service stats loadbalancer
CONTAINER                      CPU %           MEM USAGE/LIMIT      MEM %           NET I/O
loadbalancer-3                 1.67%           208.64M / N/A        N/A             61.53G/16.17G
loadbalancer-5                 1.73%           213.72M / N/A        N/A             61.7G/16.28G
loadbalancer-2                 1.59%           198.91M / N/A        N/A             61.45G/16.1G
loadbalancer-1                 1.65%           219.86M / N/A        N/A             61.57G/16.52G
loadbalancer-4                 2.05%           220.73M / N/A        N/A             61.7G/16.42G
```

Statistics are stored in a capped collection so that the database size does not grow to an unexpected size. A capped collection can be thought of like a fifo buffer: When the collection becomes full the oldest entries are removed to accomodate new statistics.

## Exporting stats

While the CLI provides a quick look at the current state of a Service, you may also want to see longer-term trends. For that purpose, Kontena can export the statistics via the [StatsD protocol](https://github.com/b/statsd_spec).

Statistics exporting can be activated on a Grid by updating it:

```
$ kontena grid update --statsd-server influx.example.com:8125 grid_name
```

To disable stats exporting use:

```
$ kontena grid update --no-statsd-server grid_name
```


**Note:** When statistics exporting is activated, Kontena will NOT send any existing statistics from the database. It will only stream new statistics.

## Where to collect stats?

It is completely up to the user to select which systems to use to collect and view statistics. The only requirement is that the selected system be able to collect stats via the StatsD protocol.

We at Kontena have been very succesfully using the [influxdata](https://influxdata.com/) stack to collect and aggregate statistics.
