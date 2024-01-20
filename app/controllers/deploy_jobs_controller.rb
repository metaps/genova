class DeployJobsController < ApplicationController
  def index
    @deploy_jobs = DeployJob.where(parse_conditions).order_by(id: 'desc').page(params[:page]).per(20)
  end

  def show
    @deploy_job = DeployJob.find(params[:id])

    render status: :not_found if @deploy_job.nil?
  end

  def download
    deploy_job = DeployJob.find(params[:id])
    return redirect_to root_path if deploy_job.nil?

    send_data(
      (deploy_job.logs || []).join("\n"),
      filename: "deployjob_#{deploy_job.id}.log",
      type: 'text/plain'
    )
  end

  private

  def parse_conditions
    conditions = {}

    # Dates are stored in ISODate and search is not implemented yet.
    if params[:keywords].present?
      pairs = params[:keywords].split(',')
      pairs.each do |pair|
        key, value = pair.split(':', 2)
        next if value.nil?

        conditions[key.strip.to_sym] = value.strip
      end
    end

    if params[:dates].present?
      dates = params[:dates].split(' - ')

      start_date = Date.strptime(dates[0], "%Y/%m/%d")&start_of_day rescue nil
      end_date = Date.strptime(dates[1], "%Y/%m/%d")&.end_of_day rescue nil

      if start_date && end_date
        conditions[:created_at] = { '$gte': start_date, '$lte': end_date }
      end
    end

    conditions
  end
end
