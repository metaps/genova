class LatestDeploymentController < ApplicationController
  def index
    @deployments = DeployJob.latest_deployment
  end
end
