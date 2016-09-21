#!/bin/bash
set -e

cd $TEST_DIR && \
  bundle install && \
  bundle exec rspec spec/
