#!/bin/bash
set -ue

cd test && \
  sudo bundle install --system && \
  rake compose:setup && \
  rake
