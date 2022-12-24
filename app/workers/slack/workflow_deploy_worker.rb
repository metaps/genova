module Slack
  class WorkflowDeployWorker < BaseWorker
    sidekiq_options queue: :slack_deploy, retry: false

    def perform(id)
      logger.info('Started Slack::WorkflowDeployWorker')

      params = Genova::Slack::SessionStore.load(id).params
      Genova::Deploy::Workflow::Runner.call(
        params[:name],
        {
          mode: DeployJob.mode.find_value(:slack),
          slack_user_id: params[:user],
          slack_user_name: params[:user_name]
        },
        Genova::Deploy::Step::SlackLogger.new(id)
      )
    rescue => e
      params.present? ? slack_notify(e, id, params[:user]) : slack_notify(e, id)
      raise e
    end
  end
end
