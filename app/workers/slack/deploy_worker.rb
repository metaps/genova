module Slack
  class DeployWorker < BaseWorker
    sidekiq_options queue: :slack_deploy, retry: false

    def perform(id)
      logger.info('Started Slack::DeployWorker')

      deploy_job_id = Genova::Slack::SessionStore.new(id).params[:deploy_job_id]

      deploy_job = DeployJob.find(deploy_job_id)
      client = Genova::Client.new(deploy_job)
      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)

      history = Genova::Slack::Interactive::History.new(deploy_job.slack_user_id)
      history.add(deploy_job)

      bot.detect_slack_deploy(deploy_job, jid)
      client.run

      bot.finished_deploy(deploy_job)
    rescue => e
      slack_notify(e, jid, id)
      raise e
    end
  end
end
