module Slack
  class DeployWorker < BaseWorker
    sidekiq_options queue: :slack_deploy, retry: false

    def perform(id)
      logger.info('Started Slack::DeployWorker')

      params = Genova::Slack::SessionStore.load(id).params
      deploy_job = DeployJob.new(id: DeployJob.generate_id,
                                 type: params[:type],
                                 alias: params[:alias],
                                 status: DeployJob.status.find_value(:in_progress),
                                 mode: DeployJob.mode.find_value(:slack),
                                 slack_user_id: params[:user],
                                 slack_user_name: params[:user_name],
                                 account: params[:account],
                                 repository: params[:repository],
                                 branch: params[:branch],
                                 tag: params[:tag],
                                 cluster: params[:cluster],
                                 run_task: params[:run_task],
                                 service: params[:service],
                                 scheduled_task_rule: params[:scheduled_task_rule],
                                 scheduled_task_target: params[:scheduled_task_target])
      deploy_job.save

      history = Genova::Slack::Interactive::History.new(deploy_job.slack_user_id)
      history.add(deploy_job)

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.detect_slack_deploy(deploy_job: deploy_job)

      Genova::Run.call(deploy_job)

      bot.finished_deploy(deploy_job: deploy_job)
    rescue => e
      params.present? ? slack_notify(e, id, params[:user]) : slack_notify(e, id)
      transaction.cancel if transaction.present?
      raise e
    end
  end
end
