class DeployJob
  include Mongoid::Document
  include Mongoid::Timestamps

  extend Enumerize

  enumerize :type, in: %i[run_task service scheduled_task]
  enumerize :status, in: %i[in_progress success failure]
  enumerize :mode, in: %i[manual auto slack]

  field :id, type: String
  field :type, type: String
  field :status, type: String
  field :mode, type: String
  field :slack_user_id, type: String
  field :slack_user_name, type: String
  field :repository, type: String
  field :account, type: String
  field :branch, type: String
  field :commit_id, type: String
  field :cluster, type: String
  field :run_task, type: String
  field :service, type: String
  field :scheduled_task_rule, type: String
  field :scheduled_task_target, type: String
  field :ssh_secret_key_path, type: String
  field :logs, type: Array
  field :task_definition_arns, type: Array
  field :started_at, type: Time
  field :finished_at, type: Time
  field :execution_time, type: Float
  field :tag, type: String

  validates :mode, :account, :repository, :cluster, :ssh_secret_key_path, presence: true
  validate :check_type
  validate :check_ssh_secret_key_path

  def self.generate_id
    Time.now.utc.strftime('%Y%m%d-%H%M%S')
  end

  def initialize(params = {})
    super

    self.id = DeployJob.generate_id
    self.account = params[:account] ||= Settings.github.account
    self.branch = params[:branch] || Settings.github.default_branch
    self.ssh_secret_key_path = params[:ssh_secret_key_path] || "#{ENV.fetch('HOME')}/.ssh/id_rsa"

    if run_task.present?
      self.type = DeployJob.type.find_value(:run_task)
    elsif service.present?
      self.type = DeployJob.type.find_value(:service)
    elsif scheduled_task_rule.present? && scheduled_task_target.present?
      self.type = DeployJob.type.find_value(:scheduled_task)
    end
  end

  def start
    self.started_at = Time.now.utc
    save
  end

  def done(task_definition_arns)
    self.status = DeployJob.status.find_value(:success).to_s
    self.task_definition_arns = task_definition_arns
    self.finished_at = Time.now.utc
    self.execution_time = finished_at.to_f - started_at.to_f
    save
  end

  def cancel
    self.status = DeployJob.status.find_value(:failure).to_s
    self.finished_at = Time.now.utc
    self.execution_time = finished_at.to_f - started_at.to_f if started_at.present?

    save
  end

  private

  def check_type
    errors[:base] << 'Please specify deploy type.' unless type.present?
  end

  def check_ssh_secret_key_path
    errors.add(:ssh_secret_key_path, "Private key does not exist. [#{ssh_secret_key_path}]") unless File.exist?(ssh_secret_key_path)
  end

  class ValidateError < Genova::Error; end
end
