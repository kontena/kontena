---
title: Stats
toc_order: 7
---
# Statistics

Kontena collects statistics of running services with the help of [cAdvisor](https://github.com/google/cadvisor). Every time an instance of a service is spun up Kontena starts to collect the statistics and stores them on the master database. The statistics can be viewed with Kontena CLI tool:
```
$ kontena service stats loadbalancer
CONTAINER                      CPU %           MEM USAGE/LIMIT      MEM %           NET I/O        
loadbalancer-3                 1.67%           208.64M / N/A        N/A             61.53G/16.17G  
loadbalancer-5                 1.73%           213.72M / N/A        N/A             61.7G/16.28G   
loadbalancer-2                 1.59%           198.91M / N/A        N/A             61.45G/16.1G   
loadbalancer-1                 1.65%           219.86M / N/A        N/A             61.57G/16.52G  
loadbalancer-4                 2.05%           220.73M / N/A        N/A             61.7G/16.42G 
```

Statistics are stored in a capped collection so that the database size does not grow to unexpected sizes. Capped collection can be thought of like a fifo buffer, when the collection gets full the oldest entries are removed to accomodate new statistics.

## Exporting stats

While CLI provides a quick look on the current state of service it would be beneficial to also see longer term trends. For that purpose Kontena can export the statistics in [StatsD protocol](https://github.com/b/statsd_spec).

Statistics exporting can be activated on a grid by updating it:
```
$ kontena grid update --statsd-server influx.example.com:8125
```


**Note:** When activating the statistics exporting Kontena will NOT send existing statistics from the database, it will only stream new statistics.


## Where to collect stats?

It is completely up to the user to select which systems to use to collect and view the statistics. Only requirement is that it can collect the stats with StatsD protocol.

We at Kontena have been using very succesfully [influxdata](https://influxdata.com/) stack to collect and aggregate statistics.

There is also a ready made plugin in the making to easily create and control influxdata based statistics collection service with Kontena. We hope to release that in coming months.