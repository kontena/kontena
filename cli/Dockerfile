FROM alpine:3.4
MAINTAINER Kontena, Inc. <info@kontena.io>

ADD https://get.docker.com/builds/Linux/x86_64/docker-1.10.3 /usr/local/bin/docker
ARG CLI_VERSION

RUN apk update && \
  apk --update add ruby ruby-json ruby-bigdecimal \
  ca-certificates libssl1.0 openssl libstdc++ && \
  gem install kontena-cli --no-rdoc --no-ri -v ${CLI_VERSION} && \
  adduser kontena -D -h /home/kontena -s /bin/sh && \
  chown -R kontena.kontena /home/kontena && \
  chmod +sx /usr/local/bin/docker

VOLUME ["/home/kontena"]
WORKDIR /home/kontena
USER kontena
ENTRYPOINT ["/usr/bin/kontena"]
