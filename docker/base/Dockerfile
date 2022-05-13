# FROM ruby:2.7.3-alpine
FROM ruby:2.7.6-alpine3.15

RUN apk --update add build-base openssh docker nodejs git tzdata vim --no-cache
ENV APP_HOME=/app

WORKDIR $APP_HOME
COPY Gemfile* $APP_HOME/

RUN echo 123
RUN bundle install -j4

COPY ./docker/base/.vimrc /root/.vimrc
COPY ./docker/base/.ssh /root/.ssh
RUN chmod 700 /root/.ssh && chmod 600 /root/.ssh/config

COPY . $APP_HOME

VOLUME $APP_HOME/public/assets
