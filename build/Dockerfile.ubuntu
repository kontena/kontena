FROM ubuntu:trusty
MAINTAINER Kontena, Inc. <info@kontena.io>

RUN echo 'deb http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu trusty main' >> /etc/apt/sources.list && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0x80f70e11f0f0d5f10cb20e62f5da5f09c3173aa6 && \
    apt-get update && \
    apt-get install -y ruby2.3 ruby2.3-dev build-essential ca-certificates libssl-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    gem install bundler

COPY server/Gemfile server/Gemfile.lock /build/server/
COPY agent/Gemfile agent/Gemfile.lock /build/agent/


RUN cd /build/server && bundle install && \
    cd /build/agent && bundle install

COPY server /build/server
COPY agent /build/agent
