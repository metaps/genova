module Slack
  class DeployWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy, retry: false

    def perform(id)
      deploy_job = DeployJob.find(id)
      deploy_client = CI::Deploy::Client.new(
        CI::Deploy::Client.mode.find_value(:slack).to_sym,
        deploy_job[:repository],
        account: deploy_job[:account],
        branch: deploy_job[:branch],
        deploy_job_id: id
      )
      bot = CI::Slack::Bot.new

      begin
        history = CI::Deploy::History.new(deploy_job[:slack_user_id])
        history.add(deploy_job[:account], deploy_job[:repository], deploy_job[:branch], deploy_job[:service])

        bot.post_detect_slack_deploy(
          deploy_job[:account],
          deploy_job[:repository],
          deploy_job[:branch],
          deploy_job[:service]
        )

        cluster = deploy_client.config.cluster_name(deploy_job[:service])
        service = deploy_client.config.service_name(deploy_job[:service])

        bot.post_started_deploy(
          deploy_client.options[:region],
          cluster,
          deploy_job[:service],
          jid,
          id
        )
        task_definition = deploy_client.exec(deploy_job[:service], Settings.slack.deploy_lock_timeout)
        bot.post_finished_deploy(cluster, service, task_definition, deploy_job[:slack_user_id])
      rescue => e
        bot.post_error(e.to_s, deploy_job[:slack_user_id], id)
        deploy_client.cancel_deploy
        raise e
      end
    end
  end
end
