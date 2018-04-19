module Slack
  class DeployWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy, retry: false

    def perform(id)
      logger.info('Started Slack::DeployWorker')

      deploy_job = DeployJob.find(id)
      client = Genova::Client.new(
        Genova::Client.mode.find_value(:slack).to_sym,
        deploy_job[:repository],
        account: deploy_job[:account],
        branch: deploy_job[:branch],
        cluster: deploy_job[:cluster],
        deploy_job_id: id,
        lock_timeout: Settings.github.deploy_lock_timeout
      )
      bot = Genova::Slack::Bot.new

      history = Genova::Slack::History.new(deploy_job[:slack_user_id])
      history.add(
        account: deploy_job[:account],
        repository: deploy_job[:repository],
        branch: deploy_job[:branch],
        cluster: deploy_job[:cluster],
        service: deploy_job[:service]
      )

      bot.post_detect_slack_deploy(
        account: deploy_job[:account],
        repository: deploy_job[:repository],
        branch: deploy_job[:branch],
        cluster: deploy_job[:cluster],
        service: deploy_job[:service]
      )

      bot.post_started_deploy(
        cluster: deploy_job[:cluster],
        service: deploy_job[:service],
        jid: jid,
        deploy_job_id: id
      )
      task_definition = client.deploy(deploy_job[:service])
      bot.post_finished_deploy(
        cluster: deploy_job[:cluster],
        service: deploy_job[:service],
        task_definition: task_definition,
        slack_user_id: deploy_job[:slack_user_id]
      )
    end
  end
end
