# ECS CI

![CircleCI](https://circleci.com/gh/metaps/ecs-ci/tree/develop.svg?style=shield&circle-token=3540dace3d93567ec1388d5359cccd1efb43a6d5)

## Description

This package provides CI environment for ECS.

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

When using ecs-ci, following configuration file is required for application.

### config/deploy.yml

Browse [sample file](https://github.com/metaps/ecs-ci/wiki/Configuration#configdeployyml).

### config/deploy/{service}.yml

For ECS deployment [use ecs_deployer](https://rubygems.org/gems/ecs_deployer).
Create a task definition file for each deployment service.

e.g.
* config/deploy/development.yml
* config/deploy/staging.yml
* config/deploy/production.yml

Browse [sample file](https://github.com/naomichi-y/ecs_deployer#task-definition).

## Setup CI Server

```bash
$ git clone https://github.com/metaps/ecs-ci.git
$ cd ecs-ci

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
$ cd ecs-ci
$ docker-compose run --rm rails thor ci help deploy

# e.g.
$ docker-compose run --rm rails thor ci:deploy -r {repository}
```

### Slack interactive deploy

If you want to deploy from Slack, you need to create a [Slack app](https://api.slack.com/apps).

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
$ docker exec -it ecs-ci-mongo /bin/bash
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
