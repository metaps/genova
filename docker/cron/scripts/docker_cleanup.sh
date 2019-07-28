#!/bin/sh

echo 'Docker cleanup'
cd /app; bundle exec thor genova:docker-cleanup
