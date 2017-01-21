#!/bin/sh
set -e

sudo mkdir /opt/kontena
sudo chown travis /opt/kontena /usr/local/bin
cd cli/omnibus

# faster bundle install
export USE_SYSTEM_GECODE=1
brew install gecode github-release

# install omnibus bundle
bundle install

# build kontena pkg
bundle exec omnibus build kontena --log-level info

# upload kontena pkg to github
github-release upload \
    --user kontena \
    --repo kontena \
    --tag $TRAVIS_TAG \
    --name "kontena-cli-osx-${TRAVIS_TAG}-amd64.pkg" \
    --file pkg/kontena-*.pkg
