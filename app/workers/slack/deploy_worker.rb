module Slack
  class DeployWorker
    include Sidekiq::Worker
    include Genova::Sidekiq::SlackAlert

    sidekiq_options queue: :slack_deploy, retry: false

    def perform(id)
      logger.info('Started Slack::DeployWorker')

      params = Genova::Slack::SessionStore.load(id).params
      deploy_job = DeployJob.create!(id: DeployJob.generate_id,
                                     type: params[:type],
                                     alias: params[:alias],
                                     status: DeployJob.status.find_value(:initial),
                                     mode: DeployJob.mode.find_value(:slack),
                                     slack_user_id: params[:user],
                                     slack_user_name: params[:user_name],
                                     slack_timestamp: id,
                                     account: Settings.github.account,
                                     repository: params[:repository],
                                     branch: params[:branch],
                                     tag: params[:tag],
                                     cluster: params[:cluster],
                                     run_task: params[:run_task],
                                     override_container: params[:override_container],
                                     override_command: params[:override_command],
                                     service: params[:service],
                                     scheduled_task_rule: params[:scheduled_task_rule],
                                     scheduled_task_target: params[:scheduled_task_target])

      history = Genova::Slack::Interactive::History.new(deploy_job.slack_user_id)
      history.add(deploy_job)

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.detect_slack_deploy(deploy_job:)
      canceller = bot.show_stop_button(deploy_job.id).ts

      transaction = Genova::Deploy::Transaction.new(params[:repository])
      bot.send_message('Please wait as other deployments are in progress.') if transaction.running?

      Genova::Deploy::Runner.new(deploy_job).run
      deploy_job.reload

      bot.delete_message(canceller)
      bot.complete_deploy(deploy_job:)
    rescue => e
      params.present? ? send_error(e, id, params[:user]) : send_error(e, id)
      raise e
    end
  end
end
