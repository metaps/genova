FROM ruby:4.0-alpine

# Upgrade the packages of the base image as well to apply security fixes.
# This layer is cached, so build with `--pull --no-cache` to pick up new fixes.
RUN apk upgrade --no-cache && \
    apk add --no-cache build-base openssh docker git gcompat tzdata yaml-dev
ENV APP_HOME=/app
ENV RUBY_YJIT_ENABLE=1

WORKDIR $APP_HOME
COPY Gemfile* $APP_HOME/

RUN bundle install -j4

COPY ./docker/base/.vimrc /root/.vimrc
COPY ./docker/base/.ssh /root/.ssh
RUN chmod 700 /root/.ssh && chmod 600 /root/.ssh/config

COPY . $APP_HOME

VOLUME $APP_HOME/public/assets
