#!/bin/bash
set -ue

gem build cli/kontena-cli.gemspec && \
  gem install --no-ri --no-rdoc *.gem

cd test && \
  bundle install --system && \
  rake compose:setup && \
  rake
