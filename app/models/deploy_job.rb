class DeployJob
  include Mongoid::Document
  include Mongoid::Timestamps

  extend Enumerize

  enumerize :type, in: %i[run_task service scheduled_task]
  enumerize :status, in: %i[initial in_progress success failure reserved_cancel cancel]
  enumerize :mode, in: %i[manual auto slack]

  field :id, type: String
  field :type, type: String
  field :status, type: String
  field :mode, type: String
  field :slack_user_id, type: String
  field :slack_user_name, type: String
  field :slack_timestamp, type: Float
  field :repository, type: String
  field :account, type: String
  field :branch, type: String
  field :tag, type: String
  field :alias, type: String
  field :commit_id, type: String
  field :cluster, type: String
  field :run_task, type: String
  field :override_container, type: String
  field :override_command, type: String
  field :service, type: String
  field :scheduled_task_rule, type: String
  field :scheduled_task_target, type: String
  field :logs, type: Array
  field :task_definition_arn, type: String
  field :task_arns, type: Array
  field :started_at, type: Time
  field :finished_at, type: Time
  field :execution_time, type: Float
  field :deployment_tag, type: String

  validates :mode, :account, :repository, :cluster, presence: true
  validate :check_type

  def self.generate_id
    Time.now.utc.strftime('%Y%m%d-%H%M%S')
  end

  def label
    "build-#{id}"
  end

  def self.latest_deployments
    deploy_job = DeployJob.collection.aggregate([
                                                  { '$sort' => { 'created_at': -1 } },
                                                  { '$match' => { '$or': [
                                                    { 'type': DeployJob.type.find_value(:service) },
                                                    { 'type': DeployJob.type.find_value(:scheduled_task) }
                                                  ] } },
                                                  { '$match' => { 'status': 'success' } },
                                                  { '$group' => {
                                                    '_id' => {
                                                      'cluster': '$cluster',
                                                      'type': '$type',
                                                      'service': '$service',
                                                      'scheduled_task_rule': '$scheduled_task_rule',
                                                      'scheduled_task_target': '$scheduled_task_target'
                                                    },
                                                    'id': { '$first' => '$_id' },
                                                    'cluster': { '$first' => '$cluster' },
                                                    'type': { '$first' => '$type' },
                                                    'service': { '$first' => '$service' },
                                                    'scheduled_task_rule': { '$first' => '$scheduled_task_rule' },
                                                    'scheduled_task_target': { '$first' => '$scheduled_task_target' },
                                                    'repository': { '$first' => '$repository' },
                                                    'branch': { '$first' => '$branch' },
                                                    'tag': { '$first' => '$tag' },
                                                    'created_at': { '$first' => '$created_at' }
                                                  } },
                                                  { '$project' => { '_id': 0 } },
                                                  { '$sort' => {
                                                    'cluster' => 1,
                                                    'type' => -1,
                                                    'service' => 1,
                                                    'scheduled_task_rule' => 1,
                                                    'scheduled_task_target' => 1
                                                  } }
                                                ])

    results = {}
    deploy_job.each do |value|
      results[value[:cluster]] = [] if results[value[:cluster]].nil?
      results[value[:cluster]] << {
        id: value[:id],
        type: value[:type],
        service: value[:service],
        scheduled_task_rule: value[:scheduled_task_rule],
        scheduled_task_target: value[:scheduled_task_target],
        repository: value[:repository],
        branch: value[:branch],
        tag: value[:tag],
        created_at: value[:created_at].in_time_zone
      }
    end

    results
  end

  def update_status_in_progress(commit_id)
    self.status = DeployJob.status.find_value(:in_progress).to_s
    self.started_at = Time.now.utc
    self.commit_id = commit_id
    save

    logger.info('Deploy Status updated to In progress.')
  end

  def update_status_complate(params = {})
    self.status = DeployJob.status.find_value(:success).to_s
    self.finished_at = Time.now.utc
    self.execution_time = finished_at.to_f - started_at.to_f
    self.task_arns = params[:task_arns] if params[:task_arns].present?
    self.task_definition_arn = params[:task_definition_arn] if params[:task_definition_arn].present?
    save

    logger.info('Deploy Status updated to Complete.')
  end

  def update_status_failure
    self.status = DeployJob.status.find_value(:failure).to_s
    self.finished_at = Time.now.utc
    self.execution_time = finished_at.to_f - started_at.to_f if started_at.present?
    save

    logger.info('Deploy Status updated to Failure.')
  end

  def update_status_reserved_cancel
    self.status = DeployJob.status.find_value(:reserved_cancel).to_s
    save

    logger.info('Deploy Status updated to Reserved cancel.')
  end

  def update_status_cancel
    self.status = DeployJob.status.find_value(:cancel).to_s
    self.finished_at = Time.now.utc
    self.execution_time = finished_at.to_f - started_at.to_f
    save

    logger.info('Deploy Status updated to Cancel.')
  end

  private

  def logger
    Genova::Logger::MongodbLogger.new(self)
  end

  def check_type
    errors[:base] << 'Please specify deploy type.' unless type.present?
  end
end
