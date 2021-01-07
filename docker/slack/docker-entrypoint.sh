#!/bin/sh

set -eu

bundle exec rackup -o 0.0.0.0 bin/slack_bot_server.ru
