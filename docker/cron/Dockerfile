FROM base

RUN apk --update add logrotate --no-cache
COPY ./docker/cron/crontabs/root /var/spool/cron/crontabs/root

COPY ./docker/cron/logrotate.d/genova /etc/logrotate.d/genova
COPY ./docker/cron/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

CMD ["/usr/local/bin/docker-entrypoint.sh"]
