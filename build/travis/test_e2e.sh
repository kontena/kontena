#!/bin/bash
set -ue

cd test && \
  bundle install && \
  rake compose:setup && \
  rake
