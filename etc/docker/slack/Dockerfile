FROM ruby:2.4.0
MAINTAINER "Naomichi Yamakita" <n.yamakita@gmail.com>

RUN apt-get update && \
  apt-get install -y \
  build-essential \
  redis-tools \
  locales && \
  localedef -f UTF-8 -i ja_JP ja_JP.UTF-8 && \
  mkdir -p /data/slack
ENV LC_ALL=ja_JP.UTF-8

WORKDIR /data/slack
RUN git clone https://github.com/slack-ruby/slack-ruby-bot-server.git

WORKDIR /data/slack/slack-ruby-bot-server/sample_apps/sample_app_mongoid
RUN gem update --system && \
  gem install bundler && \
  bundle install -j4 --path /usr/local/bundle

COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY ./config.ru ./config.ru
COPY ./mongoid.yml ./config/mongoid.yml

CMD ["/usr/local/bin/docker-entrypoint.sh"]
