module Github
  class DeployWorker
    include Sidekiq::Worker

    sidekiq_options queue: :auto_deploy, retry: false

    def perform(id)
      logger.info('Started Github::DeployWorker')

      deploy_job = DeployJob.find(id)

      deploy_client = Genova::Deploy::Client.new(
        Genova::Deploy::Client.mode.find_value(:auto).to_sym,
        deploy_job[:repository],
        account: deploy_job[:account],
        branch: deploy_job[:branch],
        deploy_job_id: id
      )
      bot = Genova::Slack::Bot.new

      begin
        deploy_config = deploy_client.config.params
        service = deploy_config.dig(:auto_deploy, :branches, deploy_job[:branch].to_sym)

        cluster = deploy_config[:cluster]
        bot.post_detect_auto_deploy(deploy_job[:account], deploy_job[:repository], deploy_job[:branch])
        bot.post_started_deploy(deploy_client.options[:region], cluster, service, jid, id)
        task_definition = deploy_client.exec(service, Settings.github.deploy_lock_timeout)

        service = deploy_config.dig(:service_mappings, service.to_sym) || service
        bot.post_finished_deploy(cluster, service, task_definition)
      rescue => e
        bot.post_error(e.to_s, nil, id)
        deploy_client.cancel_deploy
        raise e
      end
    end
  end
end
