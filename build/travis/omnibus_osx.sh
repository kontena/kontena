#!/bin/sh
set -e
wget https://github.com/aktau/github-release/releases/download/v0.6.2/linux-amd64-github-release.tar.bz2
tar xjf linux-amd64-github-release.tar.bz2
sudo mkdir /opt/kontena
sudo chown travis /opt/kontena /usr/local/bin
cd cli/omnibus
export USE_SYSTEM_GECODE=1
brew install gecode
bundle install
bundle exec omnibus build kontena --log-level info
