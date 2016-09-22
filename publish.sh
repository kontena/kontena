#!/bin/sh

curl -u $RUBYGEMS_USER https://rubygems.org/api/v1/api_key.yaml > ~/.gem/credentials; chmod 0600 ~/.gem/credentials
docker login -u kontenabot -p $DOCKER_HUB_PASSWORD
gem install --no-ri --no-doc bundler rake colorize dotenv

cd $TRAVIS_BUILD_DIR
rake release:setup
rake release:push_gem
rake release:push

rm ~/.gem/credentials
