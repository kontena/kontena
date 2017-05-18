#!/bin/bash
set -ue

CURR_BRANCH=${CURR_BRANCH:-$TRAVIS_BRANCH}
echo "Current branch: '$CURR_BRANCH' Tag: '$TRAVIS_TAG' Commit range: '$TRAVIS_COMMIT_RANGE'"
echo "Changed files:"
git diff --name-only $TRAVIS_COMMIT_RANGE

if [ "$CURR_BRANCH" != "master" ] && [ "$TRAVIS_TAG" == "" ]
then
  if [ "$TEST_DIR" == "cli" ]
  then
    if git diff --name-only $TRAVIS_COMMIT_RANGE | grep -Eqe "^cli/"
    then
      echo "Skipping $TEST_DIR test because there are no changes to $TEST_DIR in branch $CURR_BRANCH"
      exit 0
    fi
  fi

  if [ "$TEST_DIR" == "agent" ]
  then
    if git diff --name-only $TRAVIS_COMMIT_RANGE | grep -Eqe "^agent/"
      echo "Skipping $TEST_DIR test because there are no changes to $TEST_DIR in branch $CURR_BRANCH"
      exit 0
    fi
  fi

  if [ "$TEST_DIR" == "server" ]
  then
    if git diff --name-only $TRAVIS_COMMIT_RANGE | grep -Eqe "^server/")
    then
      echo "Skipping $TEST_DIR test because there are no changes to $TEST_DIR in branch $CURR_BRANCH"
      exit 0
    fi
  fi
fi

cd $TEST_DIR && bundle install --path vendor/bundle && bundle exec rspec spec/
