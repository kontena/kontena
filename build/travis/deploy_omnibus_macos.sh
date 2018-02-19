#!/bin/sh
set -ue

# install github-release
curl -sL https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 | tar -xjO > /tmp/github-release
chmod +x /tmp/github-release

# prepare install path for omnibus build
sudo mkdir -p /opt/kontena
sudo chown travis /opt/kontena

cd cli/omnibus

# faster bundle install
export USE_SYSTEM_GECODE=1

# install omnibus bundle
bundle install

# build kontena pkg
bundle exec omnibus build kontena --log-level info

# upload kontena pkg to github
/tmp/github-release upload \
    --user kontena \
    --repo kontena \
    --tag $TRAVIS_TAG \
    --name "kontena-cli-osx-${TRAVIS_TAG}-amd64.pkg" \
    --file pkg/kontena-cli-*.pkg
