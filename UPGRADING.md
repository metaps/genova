# Upgrading genova

## Upgrading from 3.2 to 4.0

Some parameter names in `settings.yml` have been changed.
If you have overwritten parameters in `settings.local.yml`, you need to change the parameter names.

* `aws.service.ecr` -> `aws.ecr`
* `deploy.polling_interval` -> `ecs.polling_interval`
* `deploy.wait_interval` -> `ecs.wait_interval`
* `thread_conversion` -> (Destroyed)

Upgrading to 4.0 requires a rebuild of genova.

```zsh
$ docker-compose stop
$ docker-compose build
$ docker-compose up -d
```

## Upgrading from 3.1 to 3.2

https://github.com/metaps/genova/issues/260

## Upgrading to >= 3.0

https://github.com/metaps/genova/issues/179
