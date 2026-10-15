# Upgrading

## Upgrading from 5.3 to 5.4

All containers now run as the non-root user `genova` instead of `root`.

Add the following parameters to `.env`.

```shell
# Owner of the genova directory
APP_UID=1000
APP_GID=1000

# Group ID of the Docker socket on the host. The containers use it to build and push images.
DOCKER_GID=999
```

You can check the values with the following commands.

```shell
$ id -u
$ id -g
$ stat -c %g /var/run/docker.sock
```

Files created by the previous root containers must be owned by the new user. Rebuild the images, change the owner of the genova directory and the Docker volumes, and then restart.

```shell
$ docker compose build base
$ docker compose build
$ sudo chown -R $(id -u):$(id -g) .
$ docker compose run --rm --no-deps --user root --entrypoint chown rails -R genova:genova /app/tmp/repos /app/tmp/cache /app/public/assets /app/node_modules
$ docker compose up -d
```

The `cron` container keeps running `crond` as root, and runs each job as the `genova` user.

## Upgrading from 5.3.0 to 5.3.1

The evaluation of `slack.permissions` has changed.
Previously, a Slack deployment was allowed if the user was permitted by either the `repository` or the `cluster` policy. Now the user must be permitted by every configured policy. A policy that is not configured is not evaluated.

If you configure both policies with different users, add the users to both policies.

```yaml
# config/settings.local.yml

slack:
  permissions:
    - policy: repository
      resources:
        - '*'
      allow_users:
        - U***
```

The `workflow` policy did not work correctly in previous versions. Workflow deployments from Slack were not restricted when the policy was not configured, and failed for all users when it was configured. After upgrading, configure the `workflow` policy if you want to restrict workflow deployments.

After changing the settings, genova must be restarted.

## Upgrading from 4.2 to 5.0

Contains updates to `node_modules`. Please update the package using the yarn command.

```shell
$ docker-compose run --rm --entrypoint yarn rails
```

## Upgrading from 4.1 to 4.2

The volume mount directory for `node_modules` has changed. Therefore, if you try to start it after building in the existing environment, you will get an `error Command "vite" not found.` error.
In that case, please run `docker volume genova_node_modules` to remove the existing volume and then run the rebuild.

## Upgrading from 4.0 to 4.1

The genova configuration parameter `slack.channel` is obsolete. Use `slack.channel_id` instead.
The `channel_id` can be obtained from the URL by opening the channel in your browser.

```yaml
# config/settings.local.yml

slack:
  -) channel: genova
  +) channel_id: C***
```

This issue is related to an Issue of slack-ruby-client used by genova.

* [translation from channel name to ID is prone to failure ](https://github.com/slack-ruby/slack-ruby-client/issues/271)
* [How to find Slack Team ID / Channel ID](https://feedly.helpscoutdocs.com/article/648-how-to-find-slack-channel-id)

After changing the settings, genova must be restarted.

## Upgrading from 3.2 to 4.0

Some parameter names in `settings.yml` have been changed.
If you have overwritten parameters in `settings.local.yml`, you need to change the parameter names.

* `aws.service.ecr` -> `ecr`
* `aws.service.ecs` -> `ecs`
* `deploy.polling_interval` -> `ecs.polling_interval`
* `deploy.wait_interval` -> `ecs.wait_interval`
* `thread_conversion` -> (Destroyed)

Upgrading to 4.0 requires a rebuild of genova.

```zsh
$ docker-compose stop
$ docker-compose build
$ docker-compose up -d
```
