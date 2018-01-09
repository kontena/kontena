FROM alpine:3.6
MAINTAINER Kontena, Inc. <info@kontena.io>

ARG CLI_VERSION

RUN apk update && \
  apk --update add ruby ruby-json ruby-bigdecimal ruby-io-console \
  curl ca-certificates libssl1.0 openssl libstdc++ && \
  curl -sL https://download.docker.com/linux/static/stable/x86_64/docker-17.06.2-ce.tgz > /tmp/docker.tgz && \
  cd /tmp && \
  tar zxf docker.tgz && \
  mv docker/docker /usr/local/bin/ && \
  rm -rf /tmp/docker* && \
  chmod +x /usr/local/bin/docker

RUN apk --update add --virtual build-dependencies ruby-dev build-base openssl-dev && \
  gem install kontena-cli --no-rdoc --no-ri -v ${CLI_VERSION} && \
  apk del build-dependencies

VOLUME ["/root"]
WORKDIR /root
ENTRYPOINT ["/usr/bin/kontena"]
