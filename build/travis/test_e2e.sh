#!/bin/bash
set -ue

if which ruby >/dev/null && which gem >/dev/null; then
  PATH="$(ruby -rubygems -e 'puts Gem.user_dir')/bin:$PATH"
else
  echo "'which ruby' or 'which gem' failed"
  exit 1
fi

cd cli && \
  gem build kontena-cli.gemspec && \
  gem install -N --user-install *.gem && \
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
