# genova

[![CircleCI](https://circleci.com/gh/metaps/genova.svg?style=shield)](https://circleci.com/gh/metaps/genova)
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE)

## Description

genova provides the ability to deploy and manage applications to [Amazon ECS](https://aws.amazon.com/ecs/).

## Overview

genova can deploy services on ECS clusters, perform standalone tasks, and execute scheduled tasks.

<img src="https://user-images.githubusercontent.com/1632478/210537641-14a7a307-7e89-4eb7-9108-bfbd3a26a18e.png" width="70%">

## Features

genova has the following features.

* YAML-based task definitions
* Various deployment methods
  * Command Line Deploy
  * Slack
  * GitHub Actions
  * GitHub Webhooks
* Provides a web console to manage deployment status

CLI deployments (including workflows) record the first field returned by `who am i`
as `linux_user_name`. The command inherits the CLI's standard input to identify the
login session before switching to the deployment account. If the command fails or
returns no user, the recorded name is `unknown`. The deploy job page shows this name
or the Slack user under **Executor**; older CLI records without a name show `unknown`.

## How Deployment Works

genova requires you to build and run a server in your local environment or in an AWS environment.
When a deployment is requested, the following steps will be taken to deploy the application.

1. Acquire the repository to be deployed.
2. Obtain the Dockerfile and the deployment configuration file (`config/deploy.yml`) in the repository.
3. Build the Dockerfile based on the deployment configuration file.
4. Push the created image to AWS ECR.
5. Define tasks based on the task definition file (`config/deploy/xxx.yml`).
6. Register the created task definitions to Amazon ECS.
7. Update the service or scheduled task. if it is a Run task, execute the task.

_The AWS resources (services and scheduled tasks) to be deployed must be created in advance._

## More detailed documentation

See the [Wiki](https://github.com/metaps/genova/wiki).
