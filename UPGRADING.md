# Upgrading

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
