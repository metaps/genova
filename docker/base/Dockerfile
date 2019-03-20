FROM ruby:2.6.1

RUN apt-get update && apt-get install -y \
    redis-tools \
    locales \
    apt-transport-https \
    software-properties-common \
    vim \
  && curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | apt-key add - \
  && add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
    $(lsb_release -cs) \
    stable" \
  && apt-get update \
  && apt-get install -y docker-ce \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ENV APP_HOME=/data/rails
RUN localedef -f UTF-8 -i ja_JP ja_JP.UTF-8

ENV LANG=ja_JP.UTF-8
ENV LC_TIME=C
ENV LC_MESSAGES=C

WORKDIR $APP_HOME
COPY Gemfile* $APP_HOME/

RUN bundle install -j4

COPY ./docker/base/.vimrc /root/.vimrc
COPY ./docker/base/.ssh /root/.ssh
RUN chmod 700 /root/.ssh

COPY . $APP_HOME
VOLUME $APP_HOME
