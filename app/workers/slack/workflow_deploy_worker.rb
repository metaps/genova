module Slack
  class WorkflowDeployWorker
    include Sidekiq::Worker
    include Genova::Sidekiq::SlackAlert

    sidekiq_options queue: :workflow_deploy, retry: false

    def perform(id)
      logger.info('Started Slack::WorkflowDeployWorker')

      params = Genova::Slack::SessionStore.load(id).params
      Genova::Deploy::Workflow::Runner.call(
        params[:name],
        Genova::Deploy::Step::SlackHook.new(id),
        mode: DeployJob.mode.find_value(:slack),
        slack_user_id: params[:user],
        slack_user_name: params[:user_name],
        slack_timestamp: id
      )
    rescue => e
      params.present? ? send_error(e, id, params[:user]) : send_error(e, id)
      raise e
    end
  end
end
