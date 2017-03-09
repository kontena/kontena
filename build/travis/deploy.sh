#!/bin/sh

set -ue

# login
docker login -u kontenabot -p $DOCKER_HUB_PASSWORD

# bintray credentials for curl
echo "machine api.bintray.com login $BINTRAY_USER password $BINTRAY_KEY" >> ~/.netrc

# install dependencies
gem install --no-ri --no-doc bundler rake colorize dotenv

cd $TRAVIS_BUILD_DIR
rake release:setup
rake release:push
rake release:push_ubuntu
