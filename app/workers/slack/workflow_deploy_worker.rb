module Slack
  class WorkflowDeployWorker < BaseWorker
    sidekiq_options queue: :slack_deploy, retry: false

    def perform(id)
      logger.info('Started Slack::WorkflowDeployWorker')

      params = Genova::Slack::SessionStore.load(id).params
      Genova::Deploy::Workflow::Runner.call(params[:name], Genova::Deploy::Workflow::SlackLogger.new(id))
    rescue => e
      params.present? ? slack_notify(e, id, params[:user]) : slack_notify(e, id)
      raise e
    end
  end
end
