module Genova
  class Client
    def initialize(deploy_job, options = {})
      @options = options

      @deploy_job = deploy_job
      @deploy_job.status = DeployJob.status.find_value(:in_progress).to_s
      raise Exceptions::ValidationError, @deploy_job.errors.full_messages[0] unless @deploy_job.save

      @logger = Genova::Logger::MongodbLogger.new(@deploy_job.id)
      @logger.level = @options[:verbose] ? :debug : Settings.logger.level
      @logger.info('Initiaized deploy client.')

      @mutex = Utils::Mutex.new("deploy-lock_#{@deploy_job.account}:#{@deploy_job.repository}")

      @code_manager = CodeManager::Git.new(
        @deploy_job.account,
        @deploy_job.repository,
        branch: @deploy_job.branch,
        tag: @deploy_job.tag,
        logger: @logger
      )
      @ecs_client = Ecs::Client.new(@deploy_job.cluster, @code_manager, logger: @logger)
    end

    def run
      @logger.info('Start deploy.')

      lock

      @deploy_job.start
      @deploy_job.commit_id = @ecs_client.ready

      @logger.info("Deploy target commit: #{@deploy_job.commit_id}")

      deploy_response = case @deploy_job.type
                        when DeployJob.type.find_value(:run_task)
                          @ecs_client.deploy_run_task(@deploy_job.run_task, @deploy_job.override_container, @deploy_job.override_command, @deploy_job.label)
                        when DeployJob.type.find_value(:service)
                          @ecs_client.deploy_service(@deploy_job.service, @deploy_job.label)
                        when DeployJob.type.find_value(:scheduled_task)
                          @ecs_client.deploy_scheduled_task(@deploy_job.scheduled_task_rule, @deploy_job.scheduled_task_target, @deploy_job.label)
                        end

      if Settings.github.deployment_tag && @deploy_job.branch.present?
        @logger.info('Add release tag.')

        @deploy_job.deployment_tag = @deploy_job.label
        @code_manager.release(@deploy_job.deployment_tag, @deploy_job.commit_id)

        @logger.info("Pushed tag: #{@deploy_job.deployment_tag}")
      end

      @deploy_job.done(deploy_response)
      @logger.info('Deployment was successful.')

      unlock
    rescue Interrupt
      @logger.error("Interrupt was detected. {\"deploy id\": #{@deploy_job.id}}")
      cancel
    rescue => e
      @logger.error(e.message)
      @logger.error(e.backtrace.join("\n")) if e.backtrace.present?
      @logger.error("Interrupt was error. {\"deploy id\": #{@deploy_job.id}}")

      cancel
      raise e unless @deploy_job.mode == DeployJob.mode.find_value(:manual)
    end

    private

    def lock
      return if @options[:force]

      lock_wait_interval = 60
      waiting_time = 0

      while @mutex.locked? || !@mutex.lock
        if waiting_time >= Settings.github.deploy_lock_timeout
          cancel
          raise Exceptions::DeployLockError, "Other deployment is in progress. [#{@deploy_job.repository}]"
        end

        @logger.warn("Deploy locked. Retry in #{lock_wait_interval} seconds.")

        sleep(lock_wait_interval)
        waiting_time += lock_wait_interval
      end
    end

    def unlock
      return if @options[:force]

      @mutex.unlock
    end

    def cancel
      @mutex.unlock
      @deploy_job.cancel
      @logger.info('Deployment has been canceled.')
    end
  end
end
