FROM node:12-alpine

ENV APP_HOME=/data/rails/frontend
WORKDIR $APP_HOME

COPY frontend $APP_HOME/

RUN yarn install
RUN yarn build

CMD ["yarn", "watch"]
