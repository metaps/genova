module Genova
  module Deploy
    class Client
      extend Enumerize

      BATCH_DELETE_MAX_IMAGE_SIZE = 100
      LOCK_WAIT_INTERVAL = 60
      IMAGE_TAG_LATEST = 'latest'.freeze

      enumerize :status, in: %i[in_progress success failure]
      enumerize :mode, in: %i[manual auto slack]

      attr_reader :options, :config

      # @param [Symbol] mode
      # @param [String] repository
      # @param [Hash] options
      def initialize(mode, repository, options = {})
        initialize_options!(options)

        @repository = repository
        @options = options

        id = @options[:deploy_job_id] || DeployJob.generate_id

        @deploy_job = DeployJob.find_or_create_by(id: id) do |deploy_job|
          @options.each do |key, value|
            deploy_job[key] = value
          end

          deploy_job.status = Genova::Deploy::Client.status.find_value(:in_progress).to_s
          deploy_job.mode = mode
          deploy_job.repository = @repository
        end

        @logger = Genova::Logger::MongodbLogger.new(@deploy_job.id)
        @logger.level = @options[:verbose] ? :debug : :info
        @logger.info('Initiaized deploy client.')

        @ecr = Aws::ECR::Client.new(profile: @options[:profile], region: @options[:region])
        @ecr_registry = ENV.fetch('AWS_ACCOUNT_ID') + '.dkr.ecr.ap-northeast-1.amazonaws.com'

        @mutex = Genova::Deploy::Mutex.new("deploy-lock_#{@options[:account]}:#{@repository}")
        @config = Genova::Deploy::Config::DeployConfig.new(@options[:account], @repository, @options[:branch])

        Genova::Git::LocalRepositoryManager.logger = @logger
        @repository_manager = Genova::Git::LocalRepositoryManager.new(@options[:account], @repository, @options[:branch])
        @config_base_path = Pathname(@repository_manager.path).join('config').to_s

        Docker.options[:read_timeout] = Settings.aws.service.ecr.read_timeout
        Docker.logger = @logger
      end

      # @param [String] service
      # @param [Integer] lock_timeout
      # @return [Aws::ECS::Types::TaskDefinition]
      def exec(service, lock_timeout = nil)
        watch_deploy do
          @logger.info('Start preparing for execute.')

          lock(lock_timeout)
          @deploy_job.start_deploy

          @repository_manager.update
          commit_id = @repository_manager.origin_last_commit_id

          @deploy_job[:commit_id] = commit_id
          @deploy_job.save

          tag_revision = "build-#{@deploy_job.id}_#{commit_id}"

          repository_names = build_images(service)
          push_images(tag_revision, repository_names)

          if @options[:push_only]
            @deploy_job.finish_deploy
            result = nil
          else
            task_definition = deploy(tag_revision, service)
            cleanup_images(repository_names)

            @deploy_job.finish_deploy(task_definition_arn: task_definition.task_definition_arn)
            result = task_definition
          end

          @logger.info('Execute completed successfully.')

          unlock
          result
        end
      end

      def cancel_deploy
        @mutex.unlock
        @deploy_job.cancel_deploy
        @logger.info('Deployment has been canceled.')
      end

      private

      # @param [Integer] lock_timeout
      def lock(lock_timeout = nil)
        watch_deploy do
          waiting_time = 0

          while @mutex.locked? || !@mutex.lock
            if lock_timeout.nil? || waiting_time >= lock_timeout
              cancel_deploy
              raise DeployLockError, "Other deployment is in progress. [#{@repository}]"
            end

            @logger.warn("Deploy locked. Retry in #{LOCK_WAIT_INTERVAL} seconds.")

            sleep(LOCK_WAIT_INTERVAL)
            waiting_time += LOCK_WAIT_INTERVAL
          end
        end
      end

      def unlock
        @mutex.unlock
      end

      # @param [Hash] options
      def initialize_options!(options)
        options[:account] ||= Settings.github.account
        options[:branch] ||= Settings.github.default_branch
        options[:interactive] ||= false
        options[:profile] ||= Settings.aws.profile
        options[:push_only] ||= false
        options[:region] ||= Settings.aws.region
        options[:verbose] ||= false
        options[:ssh_secret_key_path] ||= "#{ENV.fetch('HOME')}/.ssh/id_rsa"

        return if File.exist?(options[:ssh_secret_key_path])

        raise SshInvalidPrivateKeyError, "Private key does not exist. [#{options[:ssh_secret_key_path]}"
      end

      def watch_deploy
        yield
      rescue Interrupt
        @logger.error("Detected abort of command. {\"deploy id\": #{@deploy_job.id}}")
        cancel_deploy
      rescue => e
        @logger.error(e.message)
        @logger.error(e.backtrace.join("\n")) if e.backtrace.present?
        @logger.error("Detected error of command. {\"deploy id\": #{@deploy_job.id}}")
        cancel_deploy

        raise e
      end

      # @param [String] service
      # @return [Array]
      def build_images(service)
        @logger.info('Started building image.')

        repository_names = []
        cipher = EcsDeployer::Util::Cipher.new(profile: @options[:profile], region: @options[:region])

        params = @config.params.dig(:ecs_containers, service.to_sym)
        raise DeployConfigError, "'#{service}' parameter is not defined in 'config/deploy.yml'." if params.nil?

        params.each do |container, param|
          build = parse_docker_build(param[:build], cipher)

          docker_base_path = File.expand_path(build[:context], @config_base_path)
          docker_file_path = Pathname(docker_base_path).join(build[:docker_filename]).to_s

          raise DeployConfigError, "#{build[:docker_filename]} does not exist. [#{docker_file_path}]" unless File.exist?(docker_file_path)

          task_definition_config = @repository_manager.open_task_definition_config(service)
          container_definition = task_definition_config[:container_definitions].find { |i| i[:name] == container.to_s }
          repository_name = container_definition[:image].match(%r{/([^:]+)})[1]

          command = "docker build -t #{repository_name}:latest -f #{docker_file_path} .#{build[:build_args]}"

          deploy_command = Genova::Deploy::Command.new(work_dir: @repository_manager.path, logger: @logger)
          results = deploy_command.exec(command, docker_base_path)

          raise DockerBuildError if results[:stderr].present?

          repository_names.push(repository_name)
        end

        repository_names
      end

      # @param [Hash] build
      # @param [EcsDeployer::Util::Cipher] cipher
      # @return [Hash]
      def parse_docker_build(build, cipher)
        result = {
          build_args: ''
        }

        if build.is_a?(String)
          result[:context] = build || '.'
          result[:docker_filename] = 'Dockerfile'
        else
          result[:context] = build[:context] || '.'
          result[:docker_filename] = build[:dockerfile] || 'DockerFile'

          if build[:args].is_a?(Hash)
            build[:args].each do |key, value|
              value = cipher.decrypt(value) if cipher.encrypt_value?(value)
              result[:build_args] += " --build-arg #{key}=#{value}"
            end
          end
        end

        result
      end

      # @param [String] tag_revision
      # @param [Array] repository_names
      def push_images(tag_revision, repository_names)
        @logger.info('Started image transfer to ECR.')

        ecr_repositories = @ecr.describe_repositories[:repositories]
        authorization_token = @ecr.get_authorization_token[:authorization_data][0][:authorization_token]
        result = Base64.strict_decode64(authorization_token).split(':')
        Docker.authenticate!(username: result[0], password: result[1], serveraddress: "https://#{@ecr_registry}")

        pushed_size = 0
        repository_names.each do |repository_name|
          if ecr_repositories.find { |item| item[:repository_name] == repository_name }.nil?
            raise DockerImageError, "Repository '#{repository_name}' does not exist in ECR."
          end

          repo_tag_latest = "#{@ecr_registry}/#{repository_name}:#{IMAGE_TAG_LATEST}"
          repo_tag_version = "#{@ecr_registry}/#{repository_name}:#{tag_revision}"

          image = Docker::Image.get(repository_name)
          image.tag(repo: "#{@ecr_registry}/#{repository_name}", tag: IMAGE_TAG_LATEST)
          image.tag(repo: "#{@ecr_registry}/#{repository_name}", tag: tag_revision)

          image.push(nil, repo_tag: repo_tag_latest)
          @logger.info("Pushed image. {\"tag\": #{repo_tag_latest}}")

          image.push(nil, repo_tag: repo_tag_version)
          @logger.info("Pushed image. {\"tag\": #{repo_tag_version}}")

          pushed_size += 1
        end

        raise DockerImageError, 'Push image is not found.' if pushed_size.zero?
      end

      # @param [String] tag_revision
      # @param [String] # service
      # @return [Aws::ECS::Types::TaskDefinition]
      def deploy(tag_revision, service)
        @logger.info('Started deployment.')

        deploy_client = EcsDeployer::Client.new(
          @config.cluster_name(service),
          @logger,
          profile: @options[:profile],
          region: @options[:region]
        )
        scheduled_task_definition = deploy_scheduled_task(
          deploy_client,
          tag_revision,
          service,
          @config.params[:scheduled_tasks]
        )
        service_task_definition = deploy_service(
          deploy_client,
          tag_revision,
          service
        )

        task_definition = scheduled_task_definition if scheduled_task_definition.present?
        task_definition = service_task_definition if service_task_definition.present?
        task_definition
      end

      # @param [EcsDeployer::Task::Client] task_client
      # @param [String] task_definition_path
      # @param [String] tag_revision
      # @return [Aws::ECS::Types::TaskDefinition]
      def create_new_task(task_client, task_definition_path, tag_revision)
        @created_task = task_client.register(task_definition_path, tag: tag_revision) if @created_task.nil?
        @created_task
      end

      # @param [EcsDeployer::Client] deploy_client
      # @param [String] tag_revision
      # @param [String] service
      # @param [Hash] scheduled_tasks
      # @return [Aws::ECS::Types::TaskDefinition]
      def deploy_scheduled_task(deploy_client, tag_revision, service, scheduled_tasks)
        @logger.info('Started scheduled task deployment.')

        task_definition = nil

        if @config.params[:scheduled_tasks].present?
          scheduled_tasks.each do |scheduled_task|
            update_scheduled_task(deploy_client, tag_revision, service, scheduled_task)
          end
        else
          @logger.info('Scheduled task definition target is not registered yet.')
        end

        task_definition
      end

      # @param [EcsDeployer::Client] deploy_client
      # @param [String] tag_revision
      # @param [String] service
      # @param [Hash] scheduled_task
      def update_scheduled_task(deploy_client, tag_revision, service, scheduled_task)
        task_client = deploy_client.task
        scheduled_task_client = deploy_client.scheduled_task
        targets = []

        scheduled_task[:targets].each do |target|
          next unless target[:service] == service

          task_definition_path = File.expand_path(target[:path], @config_base_path)
          task_definition = create_new_task(task_client, task_definition_path, tag_revision)

          builder = scheduled_task_client.target_builder(target[:service])
          builder.role(target[:role]) if target[:role].present?
          builder.task_definition_arn = task_definition.task_definition_arn
          builder.task_role(target[:task_role]) if target[:task_role].present?
          builder.task_count = target[:task_count] || 1

          if target[:overrides].present?
            target[:overrides].each do |override|
              override_service = override[:service] || []
              builder.override_container(override[:name], override[:command], override_service)
            end
          end

          targets << builder.to_hash
        end

        return @logger.info("'#{service}' target is not registered yet.") if targets.count.zero?

        @logger.info("Update '#{scheduled_task[:rule]}' rule.")

        scheduled_task_client.update(
          scheduled_task[:rule],
          scheduled_task[:expression],
          targets,
          description: scheduled_task[:description]
        )
      end

      # @param [EcsDeployer::Client] deploy_client
      # @param [String] tag_revision
      # @param [String] service
      # @return [Aws::ECS::Types::TaskDefinition]
      def deploy_service(deploy_client, tag_revision, service)
        @logger.info('Started serivce deployment.')

        task_definition_path = @repository_manager.task_definition_config_path(service)
        task_definition = create_new_task(deploy_client.task, task_definition_path, tag_revision)

        service_client = deploy_client.service
        service = @config.service_name(service)

        if service_client.exist?(service)
          service_client.wait_timeout = Settings.deploy.wait_timeout
          service_client.update(service, task_definition)

          task_definition
        else
          @logger.info("Service is not registered. [#{service}]")
          return
        end
      end

      # @param [Array] repository_names
      def cleanup_images(repository_names)
        @logger.info('Started image cleanup.')

        repository_names.each do |repository_name|
          images = {}
          next_token = nil

          loop do
            describe_images = @ecr.describe_images(
              repository_name: repository_name,
              next_token: next_token
            )
            describe_images.image_details.each do |image|
              images[image.image_pushed_at.to_i] = {
                image_digest: image.image_digest
              }
            end

            next_token = describe_images.next_token
            break if next_token.nil?
          end

          images = images.sort.reverse
          images.slice!(0, Settings.aws.service.ecr.max_image_size)
          image_ids = []
          images.each do |_key, value|
            image_ids << value
          end

          next if image_ids.empty?

          if image_ids.size > BATCH_DELETE_MAX_IMAGE_SIZE
            image_ids = image_ids.slice(- BATCH_DELETE_MAX_IMAGE_SIZE, BATCH_DELETE_MAX_IMAGE_SIZE)
          end

          results = @ecr.batch_delete_image(
            repository_name: repository_name,
            image_ids: image_ids
          )

          results.image_ids.each do |image|
            @logger.info("Delete image. {\"digest\": #{image.image_digest}}")
          end

          results.failures.each do |failure|
            @logger.error('Failed to delete image. {' \
              "\"reason\": #{failure.failure_reason}, " \
              "\"code\": #{failure.failure_code}, " \
              "\"digest\": #{failure.image_id.image_digest}" \
              '}')
          end
        end
      end
    end

    class SshInvalidPrivateKeyError < Error; end
    class DeployLockError < Error; end
    class DeployConfigError < Error; end
    class DockerBuildError < Error; end
    class DockerImageError < Error; end
  end
end
