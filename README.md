# Genova

[![CircleCI](https://circleci.com/gh/metaps/genova.svg?style=shield)](https://circleci.com/gh/metaps/genova)
[![Maintainability](https://api.codeclimate.com/v1/badges/b1d9269868e13bd658a2/maintainability)](https://codeclimate.com/github/metaps/genova/maintainability)
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE)

## Description

This package provides ECS deployment function.

  * Application deployment to ECS
    * Command base deploy
    * Slack interactive deploy
    * GitHub push detect deploy
  * Support task definition for deployment
    * Encryption of environemnt variables

## Required middleware

* Docker
* Docker Compose

## Setup ECS Application

When using Genova, following configuration file is required for application.

### config/deploy.yml

Browse [sample file](https://github.com/metaps/genova/wiki/Configuration#configdeployyml).

### config/deploy/{service}.yml

For ECS deployment [use ecs_deployer](https://rubygems.org/gems/ecs_deployer).
Create a task definition file for each deployment service.

e.g.
* config/deploy/development.yml
* config/deploy/staging.yml
* config/deploy/production.yml

Browse [sample file](https://github.com/naomichi-y/ecs_deployer#task-definition).

## Setup Genova

```bash
$ git clone https://github.com/metaps/genova.git
$ cd genova

# Change settings (SLACK_*, GITHUB_* variables is optional)
$ cp config/settings.yml config/settings.local.yml
$ cp .env.default .env
# Create secret key to access GitHub
$ etc/docker/cron/.ssh/id_rsa

$ docker-compose build
$ docker-compose up [-d]
```

Application is started with following port.

* Rails: http://localhost:3000/
* c3vis: http://localhost:3001/

### Deploy

```bash
$ cd genova
$ docker-compose run --rm rails thor genova help deploy

# e.g.
$ docker-compose run --rm rails thor genova:deploy -r {repository}
```

### Slack interactive deploy

If you want to deploy from Slack, you need to create a [Slack app](https://api.slack.com/apps).

<img src="https://raw.githubusercontent.com/wiki/metaps/genova/assets/images/slack_deploy.png" width="50%">

1. Register Slack app.
2. Add key to `.env` file.
    * `SLACK_CLIENT_ID`
    * `SLACK_CLIENT_SECRET`
    * `SLACK_API_TOKEN`
    * `SLACK_CHANNEL`
    * `SLACK_VERIFICATION_TOKEN`
3. Open `docker-compose.yml` and uncomment `slack`.
4. Execute `docker-compose up`.
5. Connect to mongo container and confirm oauth key is created.

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

6. Open `docker-compose.yml` and comment out `slack`.
7. Execute `docker-compose up`.
8. Open Slack and check command can be executed.

```
@{user} help
```

### GitHub push detect deploy

If you want to execute deploy from GitHub push, register webhook URL.

1. Please add Webhook on GitHub. Open `Settings` -> `Webhooks` in repository page on GitHub.

    * Payload URL: `http://{YOUR_HOST}/api/v1/github/push`
    * Content type: `application/json`
    * Secret: {YOUR_SECRET_KEY}
    * Which events would you like to trigger this webhook?: `Just the push event.`
    * Active: Checked
2. Add GitHub access token to `.env`.
```yaml
SLACK_API_TOKEN=***
```
3. Add `auto_deploy` parameter to `deploy.yml`.

```yaml
auto_deploy:
  branches:
    master: staging
```
