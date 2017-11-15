#!/bin/bash
set -ue

cd $TEST_DIR && \
  bundle install --path vendor/bundle && \
  bundle exec rspec spec/
