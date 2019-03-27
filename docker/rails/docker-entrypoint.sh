#!/bin/sh

set -eu

if [ $RAILS_ENV = 'staging' -o $RAILS_ENV = 'production' ]; then
  bundle exec rake assets:precompile
fi

bundle exec puma
