FROM base

RUN apk add nodejs yarn --no-cache
RUN yarn

COPY ./docker/rails/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
CMD ["/usr/local/bin/docker-entrypoint.sh"]
