class DeployJobsController < ApplicationController
  def index
    @deploy_jobs = DeployJob.where(:mode.in => %i[manual auto slack]).order_by(id: 'desc').page(params[:page]).per(20)
  end

  def show
    @deploy_job = DeployJob.find(params[:id])

    render status: :not_found if @deploy_job.nil?
  end

  def latest
    deploy_job = DeployJob.collection.aggregate([
      {'$match' => {'status': 'success'}},
      {'$sort' => { 'created_at' => -1 }},
      {'$group' => {
          '_id' => { 
            'cluster': '$cluster',
            'service': '$service',
            'scheduled_task_rule': '$scheduled_task_rule',
            'scheduled_task_target': '$scheduled_task_target',
            'type': '$type'
         },
         'cluster': { '$first' => '$cluster' },
         'type': { '$first' => '$type' },
         'service': { '$first' => '$service' },
         'scheduled_task_rule': { '$first' => '$scheduled_task_rule' },
         'scheduled_task_target': { '$first' => '$scheduled_task_target' },
         'branch': { '$first' => '$branch' },
         'tag': { '$first' => '$tag' },
         'created_at': { '$first' => '$created_at' },
      }},
      {'$project' => { '_id': 0 }}
    ])

    @deployments = {}
    deploy_job.each do |value|
      cluster = value[:cluster]
      @deployments[cluster] = [] if @deployments[cluster].nil?

            @deployments[cluster] << {
              type: value[:type],
              service: value[:service],
              scheduled_task_rule: value[:scheduled_task_rule],
              scheduled_task_target: value[:scheduled_task_target],
              branch: value[:branch],
              tag: value[:tag],
              created_at: value[:created_at].in_time_zone
            }
    end
  end
end
