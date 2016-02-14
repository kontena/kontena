---
title: Wordpress Cluster
---

# Wordpress Cluster with Kontena Deploy

Building clustered Wordpress environment with [Kontena](http://www.kontena.io).

[![kontena diagram](http://image.slidesharecdn.com/kontenadockermeetuppdf-150327023059-conversion-gate01/95/building-high-availability-application-with-docker-1-638.jpg?cb=1427426338)](http://www.slideshare.net/nevalla/building-high-availability-application-with-docker)

## Usage
1. [Setup](https://github.com/kontena/kontena/tree/master/docs) Kontena environment
2. Clone this repo and example
3. Generate btsync secret key `$ docker run -i --rm --entrypoint=/usr/bin/btsync jakolehm/btsync:latest --generate-secret`
4. Update btsync secret key in `kontena.yml`
5. Run `$ kontena app deploy`

See also [simple Wordpress demo](https://github.com/kontena/examples/wordpress).

## License
Kontena software is open source, and you can use it for any purpose, personal or commercial. Kontena is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for full
