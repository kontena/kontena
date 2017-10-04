#!/bin/sh

set -ue

VERSION=$(cat ./VERSION)

echo "Checking for deployed kontena-cli gem version $VERSION..."

if gem fetch -v $VERSION kontena-cli 2>&1 | tee /tmp/gem-fetch.log | grep -q "ERROR:  Could not find a valid gem 'kontena-cli' (= $VERSION) in any repository"; then
  echo "gem version $VERSION has not yet been deployed"
elif test -e ./kontena-cli-$VERSION.gem; then
  echo "gem version $VERSION already deployed"
  ls -l kontena-cli-$VERSION.gem
  sha256sum kontena-cli-$VERSION.gem
  exit 0
else
  echo "WARNING: unknown gem fetch error, continuing anyways"
  cat /tmp/gem-fetch.log
fi

# login
curl -u $RUBYGEMS_USER https://rubygems.org/api/v1/api_key.yaml > ~/.gem/credentials; chmod 0600 ~/.gem/credentials

# install dependencies
gem install --no-ri --no-doc bundler rake colorize dotenv

cd $TRAVIS_BUILD_DIR
rake release:setup
rake release:push_gem

# cleanup
rm ~/.gem/credentials
