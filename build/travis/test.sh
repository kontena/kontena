#!/bin/bash
set -ue

cd $TEST_DIR && \
  bundle install --path vendor/bundle && \
  bundle audit check --update --ignore CVE-2018-1000539 && \ # ignore vulnerability in JSON-JWT, used by ancient Acme::Client for sending requests, not for validating.
  bundle exec rspec spec/
