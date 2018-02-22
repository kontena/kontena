#!/bin/bash
set -ue

GEM_HOME=$HOME/.gems
mkdir -p $GEM_HOME

cd cli && \
  gem build kontena-cli.gemspec && \
  gem install -N *.gem && \
  kontena -v && \
  cd ..

# Get some usable layers before compose builds
docker pull kontena/agent:edge
docker pull kontena/server:edge
docker pull kontena/cli:edge

cd test && \
  bundle install --system --without development && \
  rm Gemfile && \
  kontena -v && \
  rake compose:setup && \
  rspec spec/
