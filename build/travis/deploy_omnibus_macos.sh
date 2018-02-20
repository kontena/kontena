#!/bin/sh
set -ue

echo "decrypting kontena.p12.enc ..."
openssl aes-256-cbc -K $encrypted_12d917fc848a_key -iv $encrypted_12d917fc848a_iv -in ./build/travis/kontena.p12.enc -out kontena.p12.txt -d
cat kontena.p12.txt | base64 --decode > kontena.p12

echo "creating build.keychain"
security create-keychain -p buildpwd build.keychain
security default-keychain -s build.keychain
security unlock-keychain -p buildpwd build.keychain
security set-keychain-settings -t 3600 -u build.keychain

echo "importing kontena.p12 to build.keychain"
security import kontena.p12 -k build.keychain -P "" -T /usr/bin/productbuild
security set-key-partition-list -S apple-tool:,apple: -s -k buildpwd build.keychain

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