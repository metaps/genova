# Genova

[![CircleCI](https://circleci.com/gh/metaps/genova.svg?style=shield)](https://circleci.com/gh/metaps/genova)
[![Maintainability](https://api.codeclimate.com/v1/badges/b1d9269868e13bd658a2/maintainability)](https://codeclimate.com/github/metaps/genova/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/b1d9269868e13bd658a2/test_coverage)](https://codeclimate.com/github/metaps/genova/test_coverage)
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE)

This package provides [AWS ECS](https://aws.amazon.com/ecs/) deployment function.

## Features

* YAML based task definition
  * Support encryption of environment variables by [KMS](https://aws.amazon.com/kms/)
  * Compatible with EC2, Fargate
* Supports multiple deployment methods
  * Command base deploy
  * Slack interactive deploy
  * GitHub push detect deploy
* Provide web console
* Deployment execution
  * Build image from repository on GitHub
  * Push image to [ECR](https://aws.amazon.com/ecr/)
  * Register task
  * Support scheduled event
  * Tagging GitHub

<img src="https://raw.githubusercontent.com/wiki/metaps/genova/assets/images/overview.png" width="50%">

### Genova console

Genova provides web console.

<img src="https://raw.githubusercontent.com/wiki/metaps/genova/assets/images/console_index.png" width="80%">

You can check deployment status.

<img src="https://raw.githubusercontent.com/wiki/metaps/genova/assets/images/console_show.png" width="80%">

## Installation

When using Genova, please create following configuration file in application.

### Deploy configuration

Create `config/deploy.yml` file. Please refer to [sample](https://github.com/metaps/genova/wiki/Deploy-configuration).

### Task definition

ECS deployment uses [ecs_deployer](https://rubygems.org/gems/ecs_deployer). Create task definition file for each service to be deployed. File name uses service name of ECS.

e.g.
* `config/deploy/development.yml`
* `config/deploy/staging.yml`
* `config/deploy/production.yml`

Please refer to [sample](https://github.com/naomichi-y/ecs_deployer#task-definition).

## Setup Genova

```bash
# See https://github.com/metaps/genova/wiki/Configuration
$ cp config/settings.yml config/settings.local.yml

# Rewrite environment variable.
$ cp .env.default .env

$ docker-compose build
$ docker-compose up
```

Please open http://localhost:3000/ in the browser.

## Deploy

### Command base deploy

```bash
$ docker-compose run --rm rails thor genova help deploy

# e.g.
$ docker-compose run --rm rails thor genova:deploy -r {repository} -c {cluster} -s {service}
```

### Slack interactive deploy

If you want to deploy from Slack, you need to create a [Slack app](https://api.slack.com/apps).

<img src="https://raw.githubusercontent.com/wiki/metaps/genova/assets/images/slack_deploy.png" width="50%">

1. Create [Slack app](https://api.slack.com/apps).
    * `Features - Interactive Components`
      * Change toggle On
      * `Request URL: https://{HOST}/api/v1/slack/post`
      * Press `Save changes`
    * `Features - Bot Users`
      * `Display name`: Bot name
      * `Default username`: Bot name
      * `Always Show My Bot as Online`: `On`
      * Press `Add a Bot User`
    * `Settings - Install App`
      * Press `Install App to Workspace`
      * In Authorize page, specify channel to activate Bot.
2. Start Slack and open Bot enabled channel. Add Bot user from `Invite others to ...`.
3. Open `.env` file and add value displayed in Slack app.
    * `SLACK_CLIENT_ID`
    * `SLACK_CLIENT_SECRET`
    * `SLACK_API_TOKEN` (`Features - OAuth & Permissions - Bot User OAuth Access Token`)
    * `SLACK_CHANNEL`
    * `SLACK_VERIFICATION_TOKEN`
4. Execute `docker-compose up`.

You can execute deploy command with slack.

```
@{YOUR_BOT} help
```

### GitHub push detect deploy

If you want to execute deploy from GitHub push, register webhook URL.

1. Please add Webhook on GitHub. Open `Settings` -> `Webhooks` in repository page on GitHub.

    * Payload URL: `https://{YOUR_HOST}/api/v1/github/push`
    * Content type: `application/json`
    * Secret: `{GITHUB_SECRET_KEY}`
    * Which events would you like to trigger this webhook?: `Just the push event.`
    * Active: Checked
2. Add GitHub access token to `.env`.
```yaml
GITHUB_SECRET_KEY=***
SLACK_API_TOKEN=***
```
3. Add `auto_deploy` parameter to `deploy.yml`.

```yaml
auto_deploy:
  - branch: 'branch'
    cluster: 'cluster',
    service: 'service'
```

## For developer

### RSpec

```bash
docker-compose run --rm rails rspec
```

### Webpack

```bash
# Watch file changes
$ docker-compose run --rm node watch

# Asset build
$ docker-compose run --rm node build
```
