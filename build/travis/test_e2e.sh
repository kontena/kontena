#!/bin/bash
set -ue

if which ruby >/dev/null && which gem >/dev/null; then
  PATH="$(ruby -rubygems -e 'puts Gem.user_dir')/bin:$PATH"
  GEM_PATH="$(ruby -rubygems -e 'puts Gem.user_dir'):$GEM_PATH"
  export PATH
  export GEM_PATH
else
  echo "'which ruby' or 'which gem' failed"
  exit 1
fi

cd cli && \
  gem build kontena-cli.gemspec && \
  gem install -N --user-install *.gem

kontena -v || (echo "Can't run kontena -v"; exit 1)

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
