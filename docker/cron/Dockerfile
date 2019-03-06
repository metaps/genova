FROM base

RUN apt-get update \
  && apt-get install -y cron logrotate \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY ./docker/cron/cron.d/genova /etc/cron.d/genova
COPY ./docker/cron/cron /etc/pam.d/cron
COPY ./docker/cron/logrotate.d/rails /etc/logrotate.d/rails
RUN chmod 644 /etc/cron.d/genova && chmod 644 /etc/logrotate.d/rails

COPY ./docker/cron/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
CMD ["/usr/local/bin/docker-entrypoint.sh"]
