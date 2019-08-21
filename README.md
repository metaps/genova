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

## Usage

Please refer to [Wiki](https://github.com/metaps/genova/wiki).
