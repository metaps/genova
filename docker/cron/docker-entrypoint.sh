#!/bin/bash

set -eu

printenv | awk '{print "export " $1}' > /env.sh
cron -f
