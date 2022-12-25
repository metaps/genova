module Slack
  class WorkflowDeployWorker
    include Sidekiq::Worker
    include Genova::Sidekiq::SlackAlert

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
        Genova::Deploy::Step::SlackHook.new(id)
      )
    rescue => e
      params.present? ? send(e, id, params[:user]) : send(e, id)
      raise e
    end
  end
end
