module Genova
  class Client
    def initialize(deploy_job, options = {})
      @options = options
      @options[:lock_wait_interval] = options[:lock_wait_interval] || 60

      @deploy_job = deploy_job
      raise DeployJob::ValidateError, @deploy_job.errors.full_messages[0] unless @deploy_job.valid?

      @deploy_job.status = DeployJob.status.find_value(:in_progress).to_s
      @deploy_job.save

      @logger = Genova::Logger::MongodbLogger.new(@deploy_job.id)
      @logger.level = @options[:verbose] ? :debug : :info
      @logger.info('Initiaized deploy client.')

      @mutex = Genova::Utils::Mutex.new("deploy-lock_#{@deploy_job.account}:#{@deploy_job.repository}")

      @repository_manager = Genova::Git::LocalRepositoryManager.new(
        @deploy_job.account,
        @deploy_job.repository,
        @deploy_job.branch,
        logger: @logger
      )
      @ecs_client = Genova::Ecs::Client.new(@deploy_job.cluster, @repository_manager, logger: @logger)
    end

    def run
      @logger.info('Start deploy.')

      lock(@options[:lock_timeout])

      @deploy_job.start

      commit_id = @ecs_client.ready
      @logger.info("Commit ID: #{commit_id}")

      @deploy_job.commit_id = commit_id
      @deploy_job.cluster = @deploy_job.cluster
      @deploy_job.tag = create_tag(commit_id)

      task_definition_arns = @ecs_client.deploy_service(@deploy_job.service, @deploy_job.tag)

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
          raise DeployLockError, "Other deployment is in progress. [#{@deploy_job.repository}]"
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

    def create_tag(commit_id)
      tag = "build-#{@deploy_job.id}"

      if Settings.github.tag
        github_client = Genova::Github::Client.new(@deploy_job.account, @deploy_job.repository)
        github_client.create_tag(tag, commit_id)
      end

      tag
    end

    class DeployLockError < Error; end
    class DockerBuildError < Error; end
    class ImagePushError < Error; end
  end
end
