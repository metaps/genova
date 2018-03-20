class DeployJob
  include Mongoid::Document
  include Mongoid::Timestamps

  field :id, type: String
  field :status, type: String
  field :mode, type: String
  field :slack_user_id, type: String
  field :slack_user_name, type: String
  field :repository, type: String
  field :account, type: String
  field :branch, type: String
  field :commit_id, type: String
  field :cluster, type: String
  field :service, type: String
  field :interactive, type: Boolean
  field :profile, type: String
  field :push_only, type: Boolean
  field :region, type: String
  field :verbose, type: String
  field :ssh_secret_key_path, type: String
  field :logs, type: Array
  field :task_definition_arn, type: String
  field :started_at, type: Time
  field :finished_at, type: Time
  field :execution_time, type: Float

  def self.generate_id
    Time.now.utc.strftime('%Y%m%d-%H%M%S')
  end

  def start_deploy
    self.started_at = Time.now.utc
    save
  end

  def finish_deploy(task_definition_arn: nil)
    self.status = Genova::Deploy::Client.status.find_value(:success).to_s
    self.task_definition_arn = task_definition_arn
    self.finished_at = Time.now.utc
    self.execution_time = finished_at.to_f - started_at.to_f
    save
  end

  def cancel_deploy
    self.status = Genova::Deploy::Client.status.find_value(:failure).to_s
    self.finished_at = Time.now.utc
    self.execution_time = finished_at.to_f - started_at.to_f if started_at.present?

    save
  end
end
