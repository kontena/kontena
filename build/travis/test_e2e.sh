#!/bin/bash
set -ue

cd cli && \
  gem build cli/kontena-cli.gemspec && \
  gem install --no-ri --no-rdoc *.gem && \
  kontena -v && \
  cd ..

cd test && \
  bundle install --system --without development && \
  rm Gemfile && \
  kontena -v && \
  rake compose:setup && \
  rake
