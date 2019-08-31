FROM base

RUN apk --update add logrotate --no-cache

COPY ./docker/cron/logrotate.conf /etc
RUN chmod 644 /etc/logrotate.conf

COPY ./docker/cron/logrotate.d/genova /etc/logrotate.d
RUN chmod 644 /etc/logrotate.d/genova

COPY ./docker/cron/periodic/15min /etc/periodic/15min

CMD ["crond", "-f"]
