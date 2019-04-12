# Node.js
FROM node:8-alpine as builder

ENV APP_HOME=/data/rails

WORKDIR $APP_HOME

COPY webpack.config.js $APP_HOME/
COPY package.json $APP_HOME/

RUN yarn install

COPY . $APP_HOME
RUN yarn build

CMD ["sleep", "36000"]
VOLUME /data/rails/public/assets

# Ruby
FROM ruby:2.6-alpine

RUN apk --update add build-base openssh docker nodejs git vim --no-cache
ENV APP_HOME=/data/rails

WORKDIR $APP_HOME
COPY Gemfile* $APP_HOME/

RUN bundle install -j4

COPY ./docker/base/.vimrc /root/.vimrc
COPY ./docker/base/.ssh /root/.ssh
RUN chmod 700 /root/.ssh && chmod 600 /root/.ssh/config

COPY . $APP_HOME
COPY --from=builder /data/rails/public/assets /data/rails/public/assets

VOLUME $APP_HOME/public/assets
