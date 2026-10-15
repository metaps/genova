FROM ruby:4.0-alpine

# Match the owner of the host directory mounted at /app.
ARG APP_UID=1000
ARG APP_GID=1000

RUN apk --update add build-base openssh docker git gcompat tzdata yaml-dev --no-cache
RUN addgroup -g $APP_GID genova && adduser -D -u $APP_UID -G genova -h /home/genova genova

ENV APP_HOME=/app
ENV RUBY_YJIT_ENABLE=1

WORKDIR $APP_HOME
COPY Gemfile* $APP_HOME/

RUN bundle install -j4

COPY --chown=genova:genova ./docker/base/.vimrc /home/genova/.vimrc
COPY --chown=genova:genova ./docker/base/.ssh /home/genova/.ssh
RUN chmod 700 /home/genova/.ssh && chmod 600 /home/genova/.ssh/config

COPY --chown=genova:genova . $APP_HOME

# Named volumes are initialized with the ownership of these directories.
RUN mkdir -p $APP_HOME/public/assets $APP_HOME/tmp/repos $APP_HOME/tmp/cache $APP_HOME/node_modules && \
    chown genova:genova $APP_HOME $APP_HOME/public/assets $APP_HOME/tmp $APP_HOME/tmp/repos $APP_HOME/tmp/cache $APP_HOME/node_modules

USER genova

VOLUME $APP_HOME/public/assets
