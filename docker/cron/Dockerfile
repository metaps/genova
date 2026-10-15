FROM base

# crond must run as root. The jobs themselves run as the genova user via su-exec.
USER root
RUN apk add su-exec --no-cache

COPY ./docker/cron/periodic/hourly /etc/periodic/hourly

CMD ["crond", "-f"]
