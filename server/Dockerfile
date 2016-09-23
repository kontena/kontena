FROM alpine:3.4
MAINTAINER Kontena, Inc. <info@kontena.io>

RUN apk update && apk --update add tzdata ruby ruby-irb ruby-bigdecimal \
    ruby-io-console ruby-json ruby-rake ca-certificates libssl1.0 openssl libstdc++

ADD Gemfile /app/
ADD Gemfile.lock /app/

RUN apk --update add --virtual build-dependencies ruby-dev build-base openssl-dev && \
    gem install bundler --no-ri --no-rdoc && \
    cd /app ; bundle install --without development test && \
    apk del build-dependencies

ADD . /app
RUN chown -R nobody:nogroup /app
USER nobody

ENV RACK_ENV production
EXPOSE 9292

WORKDIR /app

CMD ["./run.sh"]
