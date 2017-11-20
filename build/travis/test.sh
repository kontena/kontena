#!/bin/bash
set -ue

cd $TEST_DIR && \
  bundle install --path vendor/bundle && \
  bundle audit check --update && \
  bundle exec rspec spec/
