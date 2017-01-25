# docker_compose.yml support


| docker-compose.yml | kontena.yml |  
| ----------------- | :----------: |
| build | ✓ |
| cap_add | ✓ |
| cap_drop | ✓ |
| command | ✓ |
| cgroup_parent | ✗ |
| container_name | ✗ |
| cpu_shares | ✓ |
| cpu_quota | ✗ |
| mem_limit | ✓ |
| memswap_limit | ✓ |
| restart_policy | ✗ |
| devices | ✗ |
| depends_on | ✓ |
| dns | ✗ |
| dns_search | ✗ |
| domainname | ✗ |
| tmpfs | ✗ |
| entrypoint | ✓ |
| env_file | ✓ |
| environment | ✓ |
| expose | v |
| extends | v |
| external_links | ✗ |
| extra_hosts | ✗ |
| group_add | ✗ |
| hostname | ✗ |
| image | ✓ |
| ipc | ✗ |
| labels | ✗ |
| links | ✓ |
| logging | ✓ |
| mac_address | x |
| network_mode | v |
| networks | ✗ |
| oom_score_adj | ✗ |
| pid | ✓ |
| ports | ✓ |
| privileged | ✓ |
| read_only | ✗ |
| security_opt | ✗ |
| shm_size | ✗ |
| stdin_open | ✗ |
| stop_grace_period | ✗ |
| stop_signal | ✗ |
| tty | ✗ |
| ulimits | ✗ |
| user | ✓ |
| working_dir | ✗ |
| volumes | ✓ <sup>*</sup>|
| volumes_from | ✓ |

<sup>*</sup> Named volumes are supported in the service declaration, but not in the top-level `volumes` key. When defining named volume in the service declaration the default driver configured by the Docker Engine will be used (in most cases, this is the local driver).
