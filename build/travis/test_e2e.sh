#!/bin/bash
set -ue

gem build cli/kontena-cli.gemspec && \
  gem install --no-ri --no-rdoc *.gem

cd test && \
  bundle install && \
  rake compose:setup && \
  rake
