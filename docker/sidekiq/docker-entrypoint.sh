#!/bin/sh

set -eu

bundle exec sidekiq -C config/sidekiq.yml
