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

## Usage

Please refer to [Wiki](https://github.com/metaps/genova/wiki).
