#!/bin/sh

set -ue

# login
curl -u $RUBYGEMS_USER https://rubygems.org/api/v1/api_key.yaml > ~/.gem/credentials; chmod 0600 ~/.gem/credentials

# install dependencies
gem install --no-ri --no-doc bundler rake colorize dotenv

cd $TRAVIS_BUILD_DIR
rake release:setup
rake release:push_gem

# cleanup
rm ~/.gem/credentials
