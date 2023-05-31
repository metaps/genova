FROM base

RUN apk add yarn --no-cache

COPY ./docker/rails/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
CMD ["/usr/local/bin/docker-entrypoint.sh"]
