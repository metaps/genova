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

CLI deployments (including workflows) record `GENOVA_DEPLOY_USER` as `linux_user_name`
when provided, with surrounding whitespace removed. If it is unset or blank, the CLI
uses the first field returned by `who am i`. The command inherits the CLI's standard
input to identify the login session before switching to the deployment account.
If the command fails or returns no user, the recorded name is `unknown`. The deploy
job page shows this name or the Slack user under **Executor**; older CLI records
without a name show `unknown`.

When running the CLI inside a container, run `who am i` on the host and pass the
result explicitly, since the container normally cannot access the host login record:

```sh
deploy_user=$(who am i | awk '{print $1}')
docker compose exec \
  -e GENOVA_DEPLOY_USER="${deploy_user:-unknown}" \
  rails bundle exec thor genova:deploy service --repository repository --service service
```

### Build and push without deploying

Add `--build-only` to `service`, `run-task`, or `scheduled-task` to register the
task definition, build images, and push them to ECR without updating an ECS
service, running a task, or updating a schedule. Existing `deploy.yml` settings
are used; no additional configuration is required.

```sh
docker compose run --rm rails bundle exec thor genova:deploy service \
  --repository repository --cluster production --service api \
  --branch develop --build-only

docker compose run --rm rails bundle exec thor genova:deploy workflow \
  --name release --build-only
```

For workflows, the option applies to every resource in every step, including
run tasks such as database migrations: their images are built, but the tasks
are not executed. Repeated build targets are processed in workflow order.

Images are pushed with both `latest` and `build-<job ID>` tags, as in a normal
deployment. `--tag` still selects a Git tag, not an ECR image tag. `--no-cache`
can be used to disable the Docker build cache. Runtime options
`--override-container` and `--override-command` cannot be combined with
`--build-only`.

Build-only jobs appear in deployment history with a **Build only** label and the
registered task definition ARN. They do not update **Latest deployment** or
create deployment tags in Git. Errors and cancellation follow the normal job
handling, and the repository lock is held throughout the operation. A failed
job may leave a registered task definition or partially pushed images; these
are not rolled back. A subsequent normal deployment still performs its own build.

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
