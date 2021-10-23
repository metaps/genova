#!/bin/sh

exec ssh -i /app/.ssh/id_rsa "$@"
