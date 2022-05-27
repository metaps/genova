module Genova
  class Run
    def self.call(deploy_job, options = {})
      logger = Genova::Logger::MongodbLogger.new(deploy_job.id)
      logger.level = options[:verbose] ? :debug : Settings.logger.level
      logger.info('Start deploy.')

      transaction = Genova::Transaction.new(deploy_job.repository, logger: logger)
      transaction.cancel if options[:force]
      transaction.begin

      deploy_job.status = DeployJob.status.find_value(:in_progress).to_s
      deploy_job.save

      code_manager = CodeManager::Git.new(
        deploy_job.repository,
        branch: deploy_job.branch,
        tag: deploy_job.tag,
        alias: deploy_job.alias,
        logger: logger
      )
      ecs_client = Ecs::Client.new(deploy_job.cluster, code_manager, logger: logger)

      deploy_job.started_at = Time.now.utc
      deploy_job.commit_id = ecs_client.ready
      deploy_job.save

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

      deploy_job.status = DeployJob.status.find_value(:success).to_s
      deploy_job.task_definition_arn = deploy_response.task_definition_arn
      deploy_job.task_arns = deploy_response.task_arns
      deploy_job.finished_at = Time.now.utc
      deploy_job.execution_time = deploy_job.finished_at.to_f - deploy_job.started_at.to_f
      deploy_job.save

      logger.info('Deployment was successful.')

      transaction.commit
    rescue Interrupt
      logger.error("Detected forced termination of program. {\"deploy id\": #{deploy_job.id}}")

      cancel(transaction, deploy_job)
    rescue => e
      logger.error("Deployment has stopped because an error has occurred. {\"deploy id\": #{deploy_job.id}}")
      logger.error(e.message)
      logger.error(e.backtrace.join("\n")) if e.backtrace.present?

      cancel(transaction, deploy_job)
      raise e
    end

    def self.cancel(transaction, deploy_job)
      transaction.cancel

      deploy_job.status = DeployJob.status.find_value(:failure).to_s
      deploy_job.finished_at = Time.now.utc
      deploy_job.execution_time = deploy_job.finished_at.to_f - deploy_job.started_at.to_f if deploy_job.started_at.present?
      deploy_job.save
    end
  end
end
