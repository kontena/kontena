#!/bin/sh

set -ue

# login
docker login -u kontenabot -p $DOCKER_HUB_PASSWORD

# install dependencies
gem install --no-ri --no-doc bundler rake colorize dotenv

cd $TRAVIS_BUILD_DIR
rake release:setup

export GA_CODE=$DOCS_GA
export HUBSPOT_CODE=$DOCS_HS
rake release:push_docs
