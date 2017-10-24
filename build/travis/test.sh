#!/bin/bash
set -ue

CURR_BRANCH=${CURR_BRANCH:-$TRAVIS_BRANCH}

declare -a CHANGED_FILES
OLD_IFS=$IFS
IFS=$'\n'
CHANGED_DIRS=$(git diff --name-only $TRAVIS_COMMIT_RANGE | cut -d"/" -f1 | uniq)
IFS=$OLD_IFS

changes_contain () {
  local seeking=$1
  local in=1
  for element in $CHANGED_DIRS; do
    if [[ $element == $seeking ]]; then
      in=0
      break
    fi
  done
  return $in
}

if [ "$CURR_BRANCH" != "master" ] && [ "$TRAVIS_TAG" == "" ]
then
  if changes_contain "$TEST_DIR"
  then
    echo "The branch '$CURR_BRANCH' contains changes to '$TEST_DIR'"
  else
    echo "Skipping tests for '$TEST_DIR' because it has not been changed in '$CURR_BRANCH'"
    exit 0
  fi
fi

cd $TEST_DIR && bundle install --path vendor/bundle && bundle exec rspec spec/
