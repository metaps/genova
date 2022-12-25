module Genova
  module Deploy
    class Runner
      class << self
        def call(deploy_job, options = {})
          logger = Genova::Logger::MongodbLogger.new(deploy_job)
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
          ecs_client = Ecs::Client.new(deploy_job, code_manager, logger: logger)

          deploy_job.started_at = Time.now.utc
          deploy_job.commit_id = ecs_client.ready
          deploy_job.save

          case deploy_job.type
          when DeployJob.type.find_value(:run_task)
            ecs_client.deploy_run_task
          when DeployJob.type.find_value(:service)
            ecs_client.deploy_service(async_wait: options[:async_wait])
          when DeployJob.type.find_value(:scheduled_task)
            ecs_client.deploy_scheduled_task
          end

          unless options[:async_wait]
            if Settings.github.deployment_tag && deploy_job.branch.present?
              logger.info("Pushed tag: #{deploy_job.deployment_tag}")
  
              deploy_job.deployment_tag = deploy_job.label
              code_manager.release(deploy_job.deployment_tag, deploy_job.commit_id)
            end
  
            deploy_job.status = DeployJob.status.find_value(:success).to_s
            deploy_job.finished_at = Time.now.utc
            deploy_job.execution_time = deploy_job.finished_at.to_f - deploy_job.started_at.to_f
            deploy_job.save
          end

          logger.info('Deployment was finished.')
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

        def cancel(transaction, deploy_job)
          transaction.cancel

          deploy_job.status = DeployJob.status.find_value(:failure).to_s
          deploy_job.finished_at = Time.now.utc
          deploy_job.execution_time = deploy_job.finished_at.to_f - deploy_job.started_at.to_f if deploy_job.started_at.present?
          deploy_job.save
        end
      end
    end
  end
end
