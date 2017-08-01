#!/bin/sh
set -ue
unset BUILD_ID
cd cli/omnibus

sudo mkdir -p /opt/kontena
sudo chown travis /opt/kontena

sudo apt-get install -y -q fakeroot

# install omnibus bundle
bundle install

# build kontena pkg
bundle exec omnibus build kontena --log-level info

# install github-release
curl -sL https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 | tar -xjO > /tmp/github-release
chmod +x /tmp/github-release

# upload kontena deb to github
/tmp/github-release upload \
    --user kontena \
    --repo kontena \
    --tag $TRAVIS_TAG \
    --name "kontena-cli_${TRAVIS_TAG#v}_amd64.deb" \
    --file pkg/kontena-cli_*.deb
