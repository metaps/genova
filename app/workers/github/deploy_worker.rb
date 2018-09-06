module Github
  class DeployWorker
    include Sidekiq::Worker

    sidekiq_options queue: :auto_deploy, retry: false

    def perform(id)
      logger.info('Started Github::DeployWorker')

      deploy_job = DeployJob.find(id)

      bot = Genova::Slack::Bot.new
      bot.post_detect_auto_deploy(
        account: deploy_job[:account],
        repository: deploy_job[:repository],
        branch: deploy_job[:branch]
      )
      bot.post_started_deploy(
        cluster: deploy_job[:cluster],
        service: deploy_job[:service],
        jid: jid,
        deploy_job_id: id
      )

      client = Genova::Client.new(
        mode: Genova::Client.mode.find_value(:auto).to_sym,
        repository: deploy_job[:repository],
        account: deploy_job[:account],
        branch: deploy_job[:branch],
        cluster: deploy_job[:cluster],
        service: deploy_job[:service],
        deploy_job_id: id,
        lock_timeout: Settings.github.deploy_lock_timeout
      )
      deploy_job = client.run

      bot.post_finished_deploy(
        account: deploy_job[:account],
        repository: deploy_job[:repository],
        cluster: deploy_job[:cluster],
        service: deploy_job[:service],
        task_definition_arn: deploy_job[:task_definition_arn],
        tag: deploy_job[:tag]
      )
    end
  end
end
