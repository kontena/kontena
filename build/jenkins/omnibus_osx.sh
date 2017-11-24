#!/bin/sh
set -e
unset BUILD_ID
rm -rf /opt/kontena/*
rm -f /usr/local/bin/kontena || true
rm -f pkg/*

cd cli/omnibus

# faster bundle install
export USE_SYSTEM_GECODE=1

source /usr/local/opt/chruby/share/chruby/chruby.sh
chruby 2.3.3

# install omnibus bundle
bundle install

# build kontena pkg
bundle exec omnibus build kontena --log-level info

# upload kontena pkg to github
/usr/local/bin/github-release upload \
    --user kontena \
    --repo kontena \
    --tag $GIT_TAG_NAME \
    --name "kontena-cli-osx-${GIT_TAG_NAME}-amd64.pkg" \
    --file pkg/kontena-cli-*.pkg
