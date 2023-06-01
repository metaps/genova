#!/bin/sh

set -eu

if [ "$RAILS_ENV" = 'production' ]; then
  bin/vite build
fi

bundle exec puma
