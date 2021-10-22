# genova

[![CircleCI](https://circleci.com/gh/metaps/genova.svg?style=shield)](https://circleci.com/gh/metaps/genova)
[![Maintainability](https://api.codeclimate.com/v1/badges/b1d9269868e13bd658a2/maintainability)](https://codeclimate.com/github/metaps/genova/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/b1d9269868e13bd658a2/test_coverage)](https://codeclimate.com/github/metaps/genova/test_coverage)
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE)

## Description

genova provides the ability to deploy and manage applications to [AWS ECS](https://aws.amazon.com/ecs/).

## Overview

By using genova, you can deploy services, execute arbitrary tasks, and execute scheduled tasks.
In addition to command line deployment, genova supports interactive deployment via Slack, deployment triggered by push using GitHub Webhook, and CI/CD integration using GitHub Actions.

<img src="https://user-images.githubusercontent.com/1632478/105207836-5c2d8180-5b8b-11eb-8fc9-4c41f47e80c6.png" width="50%">

## Features

genova has the following features.

* YAML-based task definitions
* Some deployment flows
  * Deploying from the command line
  * Interactive deployment using Slack
  * Deploying using GitHub Actions/Webhooks
* Provides a web console to manage deployment status

## How Deployment Works

genova requires you to build and run a server in your local environment or in an AWS environment.
When a deployment is requested, the following steps will be taken to deploy the application.

1. Acquire the repository to be deployed.
2. Obtain the Dockerfile and the deployment configuration file (`config/deploy.yml`) in the repository.
3. Build the Dockerfile based on the deployment configuration file.
4. Push the created image to AWS ECR.
5. Define tasks based on the task definition file (`config/deploy/xxx.yml`).
6. Register the created task definitions to AWS ECS.
7. Update the service or scheduled task. if it is a Run task, execute the task.

_The AWS resources (services and scheduled tasks) to be deployed must be created in advance._

## Files to be placed in the application repository

genova will clone your repository to build and deploy your application.
Your repository should have the following files in it.

```yaml
config
  # Deploy configuration file.
  deploy.yml

  deploy
    # Creates a task definition file based on the deployment configuration file.
    # Give it any name you like (e.g. production.yml).
    - xxx.yml
```

* [Deploy configuration](https://github.com/metaps/genova/wiki/Deploy-configuration)
* [Task configuration](https://github.com/metaps/genova/wiki/Task-configuration)

## Setup genova

```shell
# In settings.local.yml, you can customize the behavior settings of genova.
$ cp config/settings.yml config/settings.local.yml

# The .env file defines the configuration for starting genova.
$ cp .env.default .env

$ docker-compose build
$ docker-compose up
```

* [env configuration](https://github.com/metaps/genova/wiki/Environment-configuration)

Once the container has started, go to `http://localhost:3000/`, which should bring up the genova web console.

## More detailed documentation

See the [Wiki](https://github.com/metaps/genova/wiki).
