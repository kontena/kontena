#!/bin/sh
set -e
unset BUILD_ID
cd cli/omnibus

apt-get install -y -q libgecode-dev

# faster bundle install
export USE_SYSTEM_GECODE=1

# install omnibus bundle
bundle install

# build kontena pkg
bundle exec omnibus build kontena --log-level info

# install github-release
curl -sL https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 | tar -xjO > /usr/local/bin/github-release
chmod +x /usr/local/bin/github-release

# upload kontena pkg to github
/usr/local/bin/github-release upload \
    --user kontena \
    --repo kontena \
    --tag $GIT_TAG_NAME \
    --name "kontena_${GIT_TAG_NAME}_amd64.deb" \
    --file pkg/kontena-*.deb
