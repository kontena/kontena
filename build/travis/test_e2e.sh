#!/bin/bash
set -ue

cd cli && \
  gem build kontena-cli.gemspec && \
  gem install --no-ri --no-rdoc *.gem && \
  kontena -v && \
  cd ..

cd test && \
  bundle install --system --without development && \
  rm Gemfile && \
  kontena -v && \
  docker-compose down; \
  rake compose:setup && \
  docker-compose run --build test rspec spec/
