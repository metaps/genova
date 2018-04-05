FROM ruby:2.5.0
MAINTAINER "Naomichi Yamakita" <n.yamakita@gmail.com>

RUN apt-get update \
  && apt-get install -y cron \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY ./cron.d/genova /etc/cron.d/genova
COPY ./cron /etc/pam.d/cron
COPY .ssh /root/.ssh
COPY ./logrotate.d/rails /etc/logrotate.d/rails
RUN chmod 644 /etc/cron.d/genova \
  && chmod 644 /etc/logrotate.d/rails \
  && chmod 700 /root/.ssh \
  && chmod 400 /root/.ssh/id_rsa

CMD ["/usr/local/bin/docker-entrypoint.sh"]
