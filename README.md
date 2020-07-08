# genova

[![CircleCI](https://circleci.com/gh/metaps/genova.svg?style=shield)](https://circleci.com/gh/metaps/genova)
[![Maintainability](https://api.codeclimate.com/v1/badges/b1d9269868e13bd658a2/maintainability)](https://codeclimate.com/github/metaps/genova/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/b1d9269868e13bd658a2/test_coverage)](https://codeclimate.com/github/metaps/genova/test_coverage)
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE)

## Description

genova provides feature to deploy and manage applications on [AWS ECS](https://aws.amazon.com/ecs/).

## Overview

genova is integrated package for deploying applications to ECS. You can deploy services, execute tasks, and execute scheduled tasks.
As deployment method, interactive deployment using Slack, CLI, and continuous delivery with GitHub is supported.
When you request deployment, starts deployment as follows.

1. Get target repository code
2. Find Dockerfile from deploy configuration (`config/deploy.yml`)
3. Build Docker and create image
4. Create new task based on task definition (`config/deploy/*.yml`)
5. Send image to ECR based on new task definition
6. Request ECS task update
7. ECS switches to new task

<img src="https://user-images.githubusercontent.com/1632478/86935249-95fee380-c177-11ea-84bb-5c55f2ca9024.png" width="50%">

## Features

genova supports following features.

* YAML-based task definition
  * Compatible with ECS and Fargate
  * Encrypt environment variables using [KMS](https://aws.amazon.com/kms/)
* Various deployment methods
  * CLI Deploy
  * Slack interactive deploy
  * GitHub push detect deploy
* Web console
* Tagging after deployment

## Application directory structure

Please place following files in your application.

```
- config
  # Deploy configuration
  - deploy.yml

  - deploy
    # Task configurations
    - development.yml
    - staging.yml
    - production.yml
```

* [Deploy configuration](https://github.com/metaps/genova/wiki/Deploy-configuration)
* [Task configuration](https://github.com/metaps/genova/wiki/Task-configuration)

## Setup genova

```
# Please specify GitHub repository account in github.account.
$ cp config/settings.yml config/settings.local.yml
$ cp .env.default .env

$ docker-compose build
$ docker-compose up
```

* [env configuration](https://github.com/metaps/genova/wiki/env-configuration)

You can access web console by launching `http://localhost:3000/`.

## CLI Deploy

### Service deploy

```
# help
$ docker-compose run --rm rails thor genova:deploy help service

# command
$ docker-compose run --rm rails thor genova:deploy service -r {repository} -c {cluster} -s {service}

# e.g.
$ docker-compose run --rm rails thor genova:deploy service -r api -c production-app -s backend
```

## More usage and documentation

Please refer to [Wiki](https://github.com/metaps/genova/wiki).
