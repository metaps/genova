class DeployJobsController < ApplicationController
  def index
    @deploy_jobs = DeployJob.where(:mode.in => %i[manual auto slack]).order_by(id: 'desc').page(params[:page]).per(20)
  end

  def show
    @deploy_job = DeployJob.find(params[:id])

    render status: :not_found if @deploy_job.nil?
  end
end
