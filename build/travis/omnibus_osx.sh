#!/bin/sh

sudo mkdir /opt/kontena
sudo chown travis /opt/kontena /usr/local/bin
cd cli/omnibus
export USE_SYSTEM_GECODE=1
brew install gecode
bundle install
bundle exec omnibus build kontena
