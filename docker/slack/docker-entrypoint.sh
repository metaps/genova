#!/bin/sh

set -eu

if [ -z $SLACK_CLIENT_ID ]; then
  echo 'SLACK_CLIENT_ID is undefined'
  exit
fi

bundle exec rackup -o 0.0.0.0 bin/slack_bot_server.ru
