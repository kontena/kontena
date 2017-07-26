#!/bin/sh
set -e
unset BUILD_ID
cd cli/omnibus

sudo mkdir -p /opt/kontena
sudo chown travis /opt/kontena

sudo apt-get install -y -q libgecode-dev

# faster bundle install
export USE_SYSTEM_GECODE=1

# install omnibus bundle
bundle install

# build kontena pkg
bundle exec omnibus build kontena --log-level info

# install github-release
curl -sL https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 | tar -xjO > /tmp/github-release
chmod +x /tmp/github-release

# upload kontena pkg to github
/tmp/github-release upload \
    --user kontena \
    --repo kontena \
    --tag $GIT_TAG_NAME \
    --name "kontena_${GIT_TAG_NAME}_amd64.deb" \
    --file pkg/kontena-*.deb
