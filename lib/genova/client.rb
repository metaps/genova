module Genova
  class Client
    def initialize(deploy_job, options = {})
      @options = options
      @options[:lock_wait_interval] = options[:lock_wait_interval] || 60

      @deploy_job = deploy_job
      @deploy_job.status = DeployJob.status.find_value(:in_progress).to_s
      raise Exceptions::ValidationError, @deploy_job.errors.full_messages[0] unless @deploy_job.save

      @logger = Genova::Logger::MongodbLogger.new(@deploy_job.id)
      @logger.level = @options[:verbose] ? :debug : :info
      @logger.info('Initiaized deploy client.')

      @logger.warn('"github.account" parameter is deprecated. Set variable "GITHUB_ACCOUNT" instead.') if ENV['GITHUB_ACCOUNT'].nil?

      @mutex = Utils::Mutex.new("deploy-lock_#{@deploy_job.account}:#{@deploy_job.repository}")

      @code_manager = CodeManager::Git.new(
        @deploy_job.account,
        @deploy_job.repository,
        @deploy_job.branch,
        base_path: @deploy_job.base_path,
        logger: @logger
      )
      @ecs_client = Ecs::Client.new(@deploy_job.cluster, @code_manager, logger: @logger)
    end

    def run
      @logger.info('Start deploy.')

      lock(@options[:lock_timeout])

      @deploy_job.start
      @deploy_job.commit_id = @ecs_client.ready
      @deploy_job.tag = create_tag(@deploy_job.commit_id)

      @logger.info("Deploy target commit: #{@deploy_job.commit_id}")

      task_definition_arns = case @deploy_job.type
                             when DeployJob.type.find_value(:run_task)
                               @ecs_client.deploy_run_task(@deploy_job.run_task, @deploy_job.override_container, @deploy_job.override_command, @deploy_job.tag)
                             when DeployJob.type.find_value(:service)
                               [@ecs_client.deploy_service(@deploy_job.service, @deploy_job.tag)]
                             when DeployJob.type.find_value(:scheduled_task)
                               @ecs_client.deploy_scheduled_task(@deploy_job.scheduled_task_rule, @deploy_job.scheduled_task_target, @deploy_job.tag)
                             end

      if Settings.github.tag
        @logger.info("Pushed Git tag: #{@deploy_job.tag}")
        @code_manager.release(@deploy_job.tag, @deploy_job.commit_id)
      end

      @deploy_job.done(task_definition_arns)
      @logger.info('Deployment succeeded.')

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

    def lock(lock_timeout = nil)
      return if @options[:force]

      waiting_time = 0

      while @mutex.locked? || !@mutex.lock
        if lock_timeout.nil? || waiting_time >= lock_timeout
          cancel
          raise Exceptions::DeployLockError, "Other deployment is in progress. [#{@deploy_job.repository}]"
        end

        @logger.warn("Deploy locked. Retry in #{@options[:lock_wait_interval]} seconds.")

        sleep(@options[:lock_wait_interval])
        waiting_time += @options[:lock_wait_interval]
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

    def create_tag(_commit_id)
      "build-#{@deploy_job.id}"
    end
  end
end
