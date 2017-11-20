#!/bin/sh
set -ue

# install dependencies
sudo apt-get install -y -q fakeroot
gem install --no-ri --no-doc bundler rake colorize dotenv

# install github-release
curl -sL https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 | tar -xjO > /tmp/github-release
chmod +x /tmp/github-release

# bintray credentials for curl
echo "machine api.bintray.com login $BINTRAY_USER password $BINTRAY_KEY" >> ~/.netrc

# prepare install path for omnibus build
sudo install -o travis -d /opt/kontena

cd $TRAVIS_BUILD_DIR/cli
rake release:setup_omnibus release:build_omnibus
rake release:push_omnibus_ubuntu

# upload kontena-cli deb to github
/tmp/github-release upload \
    --user kontena \
    --repo kontena \
    --tag $TRAVIS_TAG \
    --name "kontena-cli_${TRAVIS_TAG#v}_amd64.deb" \
    --file ./omnibus/pkg/kontena-cli_*.deb
