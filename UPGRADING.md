# Upgrading

## Upgrading from 5.4 to 5.5

### Docker Compose and Buildx

`docker-compose.yml` now builds the `base` image as a dependency of the other services (`additional_contexts: base: service:base`). This requires Docker Compose v5 or later and Docker Buildx 0.17.0 or later. With older versions, `docker compose build` fails with an error such as `failed to get build context base` or `compose build requires buildx 0.17.0 or later`.

```shell
$ docker compose version
$ docker buildx version
```

### Rebuild and restart

The gem dependencies have been updated (e.g. Sidekiq 7.3.10), and new parameters have been added to `config/settings.yml`. Rebuild the images and restart all containers.

```shell
$ docker compose build
$ docker compose up -d
```

If the containers are not restarted, errors such as `undefined method 'note_required' for nil` may occur because the new settings are not loaded.

### New optional settings

The following settings have been added. They are optional, and the behavior does not change if they are not set.

```yaml
# config/settings.local.yml

# Require a note for deployments started by users.
deploy:
  note_required: true

# Log in to a private Docker registry before building images.
docker:
  registry:
    url: dhi.io
    # Values starting with `arn:aws:secretsmanager:` are read from Secrets Manager, others from SSM Parameter Store.
    username_secret: /genova/docker/username
    password_secret: /genova/docker/password
```

The credentials of the private registry can also be set in `.env` with `DOCKER_REGISTRY_URL`, `DOCKER_REGISTRY_USER` and `DOCKER_REGISTRY_PASSWORD`.

## Upgrading from 5.3 to 5.4

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
