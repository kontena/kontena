#!/bin/sh

if [ "$TEST_DIR" = "server" ]; then
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
  echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.0.list
  sudo apt-get update
  sudo apt-get remove -y -q --purge mongodb-org*
  sudo rm -rf /var/lib/mongodb
  sudo apt-get install -y -q -f mongodb-org-server=3.0.12
fi

gem update --system
gem install bundler-audit --no-ri --no-rdoc

if [ "$TRAVIS_COMMIT" != "" ]; then
  sed -i -e "s/:latest/:${TRAVIS_COMMIT}/g" test/docker-compose.yml
fi
