module Github
  class DeployWorker
    include Sidekiq::Worker

    sidekiq_options queue: :auto_deploy, retry: false

    def perform(id)
      deploy_job = DeployJob.find(id)

      deploy_client = CI::Deploy::Client.new(
        CI::Deploy::Client.mode.find_value(:auto).to_sym,
        deploy_job[:repository],
        account: deploy_job[:account],
        branch: deploy_job[:branch],
        deploy_job_id: id
      )
      bot = CI::Slack::Bot.new

      begin
        deploy_config = deploy_client.config.params
        environment = deploy_config.dig(:auto_deploy, :branches, deploy_job[:branch].to_sym)

        cluster = deploy_config[:cluster]
        bot.post_detect_auto_deploy(deploy_job[:account], deploy_job[:repository], deploy_job[:branch])
        bot.post_started_deploy(deploy_client.options[:region], cluster, environment, jid, id)
        task_definition = deploy_client.exec(environment, Settings.github.deploy_lock_timeout)

        service = deploy_config.dig(:service_mappings, environment.to_sym) || environment
        bot.post_finished_deploy(cluster, service, task_definition)
      rescue => e
        bot.post_error(e.to_s, nil, id)
        deploy_client.cancel_deploy
        raise e
      end
    end
  end
end
