#!/bin/sh

docker login -u kontenabot -p $DOCKER_HUB_PASSWORD
gem install --no-ri --no-doc bundler rake colorize dotenv
cd $TRAVIS_BUILD_DIR
rake release:setup
rake release:push
