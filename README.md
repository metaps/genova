# Genova

[![CircleCI](https://circleci.com/gh/metaps/genova.svg?style=shield)](https://circleci.com/gh/metaps/genova)
[![Maintainability](https://api.codeclimate.com/v1/badges/b1d9269868e13bd658a2/maintainability)](https://codeclimate.com/github/metaps/genova/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/b1d9269868e13bd658a2/test_coverage)](https://codeclimate.com/github/metaps/genova/test_coverage)
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE)

This package provides [AWS ECS](https://aws.amazon.com/ecs/) deployment function.

## Table of contents

* [Features](#features)
* [Required middleware](#required-middleware)
* [Setup ECS Application](#setup-ecs-application)
  * [Deploy config](#deploy-config)
  * [Taks definition config](#task-definition-config)
* [Setup Genova](#setup-genova)
* [Deploy](#deploy)
  * [Command base deploy](#command-base-deploy)
  * [Slack interactive deploy](#slack-interactive-deploy)
  * [GitHub push detect deploy](#github-push-detect-deploy)

## Features

* YAML based task definition
  * Support encryption of environment variables by [KMS](https://aws.amazon.com/kms/)
* Supports multiple deployment methods
  * Command base deploy
  * Slack interactive deploy
  * GitHub push detect deploy
* Provide web console
* Deployment execution
  * Build image from repository on GitHub
  * Push image to [ECR](https://aws.amazon.com/ecr/)
  * Create service
  * Update service
  * Support scheduled event
  * Rotation cleanup of repository on ECR

<img src="https://raw.githubusercontent.com/wiki/metaps/genova/assets/images/overview.png" width="50%">

### Genova console

Genova provides web console.

<img src="https://raw.githubusercontent.com/wiki/metaps/genova/assets/images/console_index.png" width="80%">

You can check deployment status.

<img src="https://raw.githubusercontent.com/wiki/metaps/genova/assets/images/console_show.png" width="80%">

## Required middleware

* Docker >=1.13
* Docker Compose

Source code must be managed on GitHub. Also, please register `id_rsa.pub` in `Deploy Keys`.

## Setup ECS Application

When using Genova, please create following configuration file in application.

### Deploy config

Create `config/deploy.yml` file. Please refer to [sample](https://github.com/metaps/genova/wiki/Configuration#configdeployyml).

### Task definition config

ECS deployment uses [ecs_deployer](https://rubygems.org/gems/ecs_deployer). Create task definition file for each service to be deployed. File name uses service name of ECS.

e.g.
* `config/deploy/development.yml`
* `config/deploy/staging.yml`
* `config/deploy/production.yml`

Please refer to [sample](https://github.com/naomichi-y/ecs_deployer#task-definition).

## Setup Genova

```bash
$ git clone https://github.com/metaps/genova.git
$ cd genova

# See https://github.com/metaps/genova/wiki/Configuration
$ cp config/settings.yml config/settings.local.yml
$ cp .env.default .env

$ docker-compose build
$ docker-compose up
```

Please open http://localhost:3000/ in the browser.

## Deploy

### Command base deploy

```bash
$ cd genova
$ docker-compose run --rm rails thor genova help deploy

# e.g.
$ docker-compose run --rm rails thor genova:deploy -r {repository} -c {cluster} -s {service}
```

### Slack interactive deploy

If you want to deploy from Slack, you need to create a [Slack app](https://api.slack.com/apps).

<img src="https://raw.githubusercontent.com/wiki/metaps/genova/assets/images/slack_deploy.png" width="50%">

1. Execute `docker-compose stop`.
2. Register [Slack app](https://api.slack.com/apps).
    * Interactive Components
      * `Request URL: http://{YOUR_HOST}/api/v1/slack/post`
    * Bot Users
      * `Add a Bot User`
    * Install App
      * `Install App to Workspace`
3. Add bot to channel
4. Add key to `.env` file.
    * `SLACK_CLIENT_ID`
    * `SLACK_CLIENT_SECRET`
    * `SLACK_API_TOKEN`
    * `SLACK_CHANNEL`
    * `SLACK_VERIFICATION_TOKEN`
5. Open `docker-compose.yml` and uncomment `slack`.
6. Execute `docker-compose up`.
7. Connect to mongo container and confirm OAuth key was created.

```bash
$ docker exec -it genova-mongo /bin/bash
$ mongo
> show dbs;
admin                   0.000GB
bot-server_development  0.000GB
local                   0.000GB
> use bot-server_development
switched to db bot-server_development
> show collections;
teams
> db.teams.find();
{ "_id" : ObjectId("59cb507945a1d50005001b0a"), "active" : true, "token" : "***", "team_id" : "***", "name" : "Metaps", "domain" : "metaps", "updated_at" : ISODate("2017-09-27T07:17:13.545Z"), "created_at" : ISODate("2017-09-27T07:17:13.545Z") }
```

8. Open `docker-compose.yml` and comment out `slack`.
9. Execute `docker-compose up`.
10. Open Slack and check command can be executed.

```
@{YOUR_BOT} help
```

### GitHub push detect deploy

If you want to execute deploy from GitHub push, register webhook URL.

1. Please add Webhook on GitHub. Open `Settings` -> `Webhooks` in repository page on GitHub.

    * Payload URL: `http://{YOUR_HOST}/api/v1/github/push`
    * Content type: `application/json`
    * Secret: `{GITHUB_SECRET_KEY}`
    * Which events would you like to trigger this webhook?: `Just the push event.`
    * Active: Checked
2. Add GitHub access token to `.env`.
```yaml
GITHUB_OAUTH_TOKEN=***
GITHUB_SECRET_KEY=***
SLACK_API_TOKEN=***
```
3. Add `auto_deploy` parameter to `deploy.yml`.

```yaml
auto_deploy:
  branches:
    master: staging
```
