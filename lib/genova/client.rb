module Genova
  class Client
    extend Enumerize

    enumerize :status, in: %i[in_progress success failure]
    enumerize :mode, in: %i[manual auto slack]

    def initialize(options = {})
      options[:mode] ||= Genova::Client.mode.find_value(:manual).to_sym
      options[:account] ||= Settings.github.account
      options[:branch] ||= Settings.github.default_branch
      options[:profile] ||= Settings.aws.profile
      options[:region] ||= Settings.aws.region
      options[:verbose] ||= false
      options[:ssh_secret_key_path] ||= "#{ENV.fetch('HOME')}/.ssh/id_rsa"
      options[:lock_wait_interval] = 60
      options[:force] ||= false

      validate_options(options)

      @repository = options[:repository]
      @options = options

      id = @options[:deploy_job_id] || DeployJob.generate_id

      @deploy_job = DeployJob.find_or_create_by(id: id) do |deploy_job|
        @options.each do |key, value|
          deploy_job[key] = value
        end

        deploy_job.status = Genova::Client.status.find_value(:in_progress).to_s
        deploy_job.mode = options[:mode]
        deploy_job.repository = @repository
      end

      @logger = Genova::Logger::MongodbLogger.new(@deploy_job.id)
      @logger.level = @options[:verbose] ? :debug : :info
      @logger.info('Initiaized deploy client.')

      @mutex = Genova::Utils::Mutex.new("deploy-lock_#{@options[:account]}:#{@repository}")

      @repository_manager = Genova::Git::LocalRepositoryManager.new(
        @options[:account],
        @repository,
        @options[:branch],
        logger: @logger
      )
      @ecs_client = Genova::Ecs::Client.new(
        @options[:cluster],
        @repository_manager,
        logger: @logger,
        profile: @options[:profile],
        region: @options[:region]
      )
    end

    def run
      @logger.info('Start deploy.')

      pre_process
      tag_revision = Genova::Docker::Client.build_tag_revision(@deploy_job.id, @deploy_job[:commit_id])

      @ecs_client.ready
      task_definition = @ecs_client.deploy_service(@options[:service], tag_revision)

      post_process(task_definition)

      @logger.info('Deployment succeeded.')

      unlock
      task_definition
    rescue Interrupt
      @logger.error("Interrupt was detected. {\"deploy id\": #{@deploy_job.id}}")
      cancel
    rescue => e
      @logger.error(e.message)
      @logger.error(e.backtrace.join("\n")) if e.backtrace.present?
      @logger.error("Interrupt was error. {\"deploy id\": #{@deploy_job.id}}")

      cancel
      raise e unless @mode == Genova::Client.mode.find_value(:manual)
    end

    private

    def validate_options(options)
      raise OptionValidateError, 'Please specify account name of GitHub in \'config/settings.local.yml\'.' if options[:account].empty?
      raise OptionValidateError, 'Please specify repository name.' if options[:repository].nil?
      raise OptionValidateError, 'Please specify cluster name.' if options[:cluster].nil?

      return if File.exist?(options[:ssh_secret_key_path])
      raise OptionValidateError, "Private key does not exist. [#{options[:ssh_secret_key_path]}"
    end

    def lock(lock_timeout = nil)
      return if @options[:force]

      waiting_time = 0

      while @mutex.locked? || !@mutex.lock
        if lock_timeout.nil? || waiting_time >= lock_timeout
          cancel
          raise DeployLockError, "Other deployment is in progress. [#{@repository}]"
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

    def pre_process
      @logger.info('Started pre process')

      lock(@options[:lock_timeout])

      @deploy_job.start_deploy
      @deploy_job[:commit_id] = @repository_manager.origin_last_commit_id
      @deploy_job[:cluster] = @options[:cluster]
    end

    def post_process(task_definition)
      @deploy_job.finish_deploy(task_definition_arn: task_definition.task_definition_arn)
    end

    def cancel
      @mutex.unlock
      @deploy_job.cancel_deploy
      @logger.info('Deployment has been canceled.')
    end

    class OptionValidateError < Error; end
    class DeployLockError < Error; end
    class DockerBuildError < Error; end
    class ImagePushError < Error; end
  end
end
