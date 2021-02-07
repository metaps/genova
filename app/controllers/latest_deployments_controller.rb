class LatestDeploymentsController < ApplicationController
  def index
    @deployments = DeployJob.latest_deployments
  end
end
