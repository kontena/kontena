#!/bin/sh

sudo mkdir /opt/kontena
cd cli/omnibus
export USE_SYSTEM_GECODE=1
brew install gecode
bundle install
sudo bundle exec omnibus build kontena
