class DeployJobsController < ApplicationController
  def index
    @deploy_jobs = DeployJob.where(parse_conditions).order_by(id: 'desc').page(params[:page]).per(20)
  end

  def show
    @deploy_job = DeployJob.find(params[:id])

    render status: :not_found if @deploy_job.nil?
  end

  private

  def parse_conditions
    conditions = {}

    if params[:search].present?
      pairs = params[:search].split(',')
      pairs.each do |pair|
        key, value = pair.split(':')
        next if value.nil?
        conditions[key.strip.to_sym] = value.strip
      end
    end

    conditions
  end
end
