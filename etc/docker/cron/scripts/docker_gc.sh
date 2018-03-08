#!/bin/bash

. /env.sh
cd /data/rails; bundle exec thor ci:docker-gc
