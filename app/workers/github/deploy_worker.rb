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
        cluster: deploy_job[:cluster],
        service: deploy_job[:service],
        deploy_job_id: id
      )
      bot = Genova::Slack::Bot.new

      begin
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
        task_definition = deploy_client.exec(deploy_job[:service], Settings.github.deploy_lock_timeout)

        bot.post_finished_deploy(
          cluster: deploy_job[:cluster],
          service: deploy_job[:service],
          task_definition: task_definition
        )
      rescue => e
        bot.post_error(
          message: e.to_s,
          deploy_job_id: id
        )
        deploy_client.cancel_deploy
        raise e
      end
    end
  end
end
