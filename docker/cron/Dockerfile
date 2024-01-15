FROM base

COPY ./docker/cron/periodic/hourly /etc/periodic/15min

CMD ["crond", "-f"]
