module Genova
  class Run
    def self.call(deploy_job, options = {})
      logger = Genova::Logger::MongodbLogger.new(deploy_job.id)
      logger.level = options[:verbose] ? :debug : Settings.logger.level
      logger.info('Start deploy.')

      deploy_job.status = DeployJob.status.find_value(:in_progress).to_s
      code_manager = CodeManager::Git.new(
        deploy_job.account,
        deploy_job.repository,
        branch: deploy_job.branch,
        tag: deploy_job.tag,
        logger: logger
      )
      ecs_client = Ecs::Client.new(deploy_job.cluster, code_manager, logger: logger)

      deploy_job.start
      deploy_job.commit_id = ecs_client.ready

      deploy_response = case deploy_job.type
                        when DeployJob.type.find_value(:run_task)
                          ecs_client.deploy_run_task(deploy_job.run_task, deploy_job.override_container, deploy_job.override_command, deploy_job.label)
                        when DeployJob.type.find_value(:service)
                          ecs_client.deploy_service(deploy_job.service, deploy_job.label)
                        when DeployJob.type.find_value(:scheduled_task)
                          ecs_client.deploy_scheduled_task(deploy_job.scheduled_task_rule, deploy_job.scheduled_task_target, deploy_job.label)
                        end

      if Settings.github.deployment_tag && deploy_job.branch.present?
        logger.info("Pushed tag: #{deploy_job.deployment_tag}")

        deploy_job.deployment_tag = deploy_job.label
        code_manager.release(deploy_job.deployment_tag, deploy_job.commit_id)
      end

      deploy_job.done(deploy_response)
      logger.info('Deployment was successful.')
    rescue Interrupt
      logger.error("Detected forced termination of program. {\"deploy id\": #{deploy_job.id}}")

      Genova::Utils::DeployTransaction.new(deploy_job.repository).cancel
      deploy_job.cancel
    rescue => e
      logger.error("Deployment has stopped because an error has occurred. {\"deploy id\": #{deploy_job.id}}")
      logger.error(e.message)
      logger.error(e.backtrace.join("\n")) if e.backtrace.present?

      Genova::Utils::DeployTransaction.new(deploy_job.repository).cancel
      deploy_job.cancel

      raise e unless deploy_job.mode == DeployJob.mode.find_value(:manual)
    end
  end
end
