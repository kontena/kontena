#!/bin/bash
set -ue

cd test && \
  bundle install --system && \
  rake compose:setup && \
  rake
