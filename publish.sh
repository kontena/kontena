#!/bin/sh

gem install --no-ri --no-doc bundler rake colorize dotenv
cd $TRAVIS_BUILD_DIR
rake release:setup
rake release:build
