#!/bin/sh

echo 'Docker cleanup'
cd /data/rails; bundle exec thor genova:docker-cleanup
