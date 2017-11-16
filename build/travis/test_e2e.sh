#!/bin/bash
set -ue

cd test && \
  bundle install --path vendor/bundle && \
  bundle exec rake compose:setup && \
  bundle exec rake
