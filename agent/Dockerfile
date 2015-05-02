FROM ubuntu:trusty
MAINTAINER jari@kontena.io

RUN echo 'deb http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu trusty main' >> /etc/apt/sources.list && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0x80f70e11f0f0d5f10cb20e62f5da5f09c3173aa6 && \
    apt-get update

ADD Gemfile /app/
ADD Gemfile.lock /app/

ENV CADVISOR_URL http://cadvisor:8080/api/v1.2/docker/

RUN apt-get install -y ruby2.2 ruby2.2-dev build-essential libssl-dev ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    gem install bundler && \
    cd /app ; bundle install --without development test && \
    apt-get remove -y --purge ruby2.2-dev build-essential gcc g++ dpkg-dev make && \
    apt-get clean && \
    apt-get autoremove -y --purge

ADD . /app

CMD ["/app/bin/kontena-agent"]
