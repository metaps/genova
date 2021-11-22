FROM node:16-alpine

ENV APP_HOME=/app/frontend

WORKDIR $APP_HOME
COPY frontend $APP_HOME/

RUN yarn
RUN yarn build

CMD ["yarn", "watch"]
