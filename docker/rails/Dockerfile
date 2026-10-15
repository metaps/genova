FROM base

USER root
RUN apk add nodejs yarn --no-cache
USER genova

RUN yarn

COPY ./docker/rails/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
CMD ["/usr/local/bin/docker-entrypoint.sh"]
