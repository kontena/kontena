FROM alpine:3.5
MAINTAINER Kontena, Inc. <info@kontena.io>

ADD https://get.docker.com/builds/Linux/x86_64/docker-latest.tgz /tmp/docker-latest.tgz
RUN tar --strip-components=1 -xvzf /tmp/docker-latest.tgz -C /usr/local/bin
RUN rm /tmp/docker-latest.tgz

ARG CLI_VERSION

RUN apk update && \
  apk --update add ruby ruby-json ruby-bigdecimal ruby-io-console \
  ca-certificates libssl1.0 openssl libstdc++ && \
  gem install kontena-cli --no-rdoc --no-ri -v ${CLI_VERSION} && \
  chmod +x /usr/local/bin/docker

VOLUME ["/root"]
WORKDIR /root
ENTRYPOINT ["/usr/bin/kontena"]
