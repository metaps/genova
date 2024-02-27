#!/bin/sh

exec ssh -i /app/${SSH_PRIVATE_KEY} "$@"
