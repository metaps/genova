#!/bin/bash

. /env.sh
cd /data/rails; bundle exec thor genova:docker-cleanup
