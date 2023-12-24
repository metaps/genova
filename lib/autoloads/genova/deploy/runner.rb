module Genova
  module Deploy
    class Runner
      def initialize(deploy_job, options = {})
        @deploy_job = deploy_job
        @options = options

        @logger = Genova::Logger::MongodbLogger.new(@deploy_job)
        @logger.level = options[:verbose] ? :debug : Settings.logger.level
        @logger.info(Genova::Version::LONG_STRING)
      end

      def run
        transaction = Genova::Deploy::Transaction.new(@deploy_job.repository, logger: @logger, force: @options[:force])
        transaction.begin

        @logger.info('Start deployment.')
        ecs = Ecs::Client.new(@deploy_job, @options, @logger)

        @deploy_job.reload
        raise Interrupt if @deploy_job.status == DeployJob.status.find_value(:reserved_cancel)

        @deploy_job.update_status_provisioning(ecs.ready)

        case @deploy_job.type
        when DeployJob.type.find_value(:run_task)
          ecs.deploy_run_task
        when DeployJob.type.find_value(:service)
          ecs.deploy_service
        when DeployJob.type.find_value(:scheduled_task)
          ecs.deploy_scheduled_task
        end

        transaction.commit
      rescue Interrupt => e
        @logger.info('Detect forced termination.')

        transaction.cancel
        @deploy_job.update_status_cancel

        error_handler(e)
      rescue => e
        @logger.error('Deployment failed.')
        @logger.error(e.message)
        @logger.error(e.backtrace.join("\n"))

        transaction.cancel
        @deploy_job.update_status_failure

        error_handler(e)
      end

      def error_handler(e)
        raise e unless @deploy_job.mode == DeployJob.mode.find_value(:manual)

        exit 1
      end
    end
  end
end
