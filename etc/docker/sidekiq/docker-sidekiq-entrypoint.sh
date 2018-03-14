#!/bin/bash

set -eu

bundle exec sidekiq -C config/sidekiq.yml
