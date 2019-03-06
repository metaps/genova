FROM ruby:2.6.1

WORKDIR /tmp
RUN apt-get update && apt-get install -y \
    build-essential \
    redis-tools \
    locales \
    apt-transport-https \
    ca-certificates \
    gnupg2 \
    software-properties-common \
    libcurl4-gnutls-dev \
    libexpat1-dev \
    libz-dev libssl-dev \
    gettext \
    cron \
    logrotate \
    vim \
    nodejs \
  && apt-get remove -y git
RUN curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | apt-key add - \
  && add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
    $(lsb_release -cs) \
    stable" \
  && apt-get update \
  && apt-get install -y docker-ce \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN localedef -f UTF-8 -i ja_JP ja_JP.UTF-8 \
  && mkdir -p /data/rails

ENV LANG=ja_JP.UTF-8
ENV LC_TIME=C
ENV LC_MESSAGES=C

WORKDIR /data/rails
COPY Gemfile* /data/rails/

RUN gem update --system 3.0.2 \
  && gem install bundler \
  && bundle install -j4 --path /usr/local/bundle
RUN ln -s /usr/bin/nodejs /usr/bin/node

COPY ./docker/base/.vimrc /root/.vimrc
COPY ./docker/base/.ssh /root/.ssh
RUN chmod 700 /root/.ssh

COPY ./docker/cron/cron.d/genova /etc/cron.d/genova
COPY ./docker/cron/cron /etc/pam.d/cron
COPY ./docker/cron/logrotate.d/rails /etc/logrotate.d/rails
RUN chmod 644 /etc/cron.d/genova && chmod 644 /etc/logrotate.d/rails

RUN chmod 644 /etc/cron.d/genova \
  && chmod 644 /etc/logrotate.d/rails

COPY ./docker/rails/docker-entrypoint-rails.sh /usr/local/bin/docker-entrypoint-rails.sh
COPY ./docker/cron/docker-entrypoint-cron.sh /usr/local/bin/docker-entrypoint-cron.sh
COPY ./docker/sidekiq/docker-entrypoint-sidekiq.sh /usr/local/bin/docker-entrypoint-sidekiq.sh
COPY ./docker/slack/docker-entrypoint-slack.sh /usr/local/bin/docker-entrypoint-slack.sh

COPY . /data/rails
VOLUME /data/rails
