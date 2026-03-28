module Genova
  module Ecs
    class Client
      def initialize(deploy_job, options, logger)
        @deploy_job = deploy_job
        @code_manager = CodeManager::Git.new(
          @deploy_job.repository,
          branch: @deploy_job.branch,
          tag: @deploy_job.tag,
          alias: @deploy_job.alias,
          logger:
        )
        @options = options
        @logger = logger
        @task_definitions = {}

        @docker_client = Genova::Docker::Client.new(@code_manager, logger)
        @docker_client.no_cache = @options[:no_cache] if @options[:no_cache].present?

        @ecr_client = Genova::Ecr::Client.new(logger)
      end

      def deploy_run_task
        @logger.info('Start run task.')
        ready(:run_task)

        run_task_config = @code_manager.deploy_config.find_run_task(@deploy_job.cluster, @deploy_job.run_task).deep_dup
        resolve_container_overrides!(run_task_config)
        merge_container_overrides_into_task_overrides!(run_task_config)

        if @deploy_job.override_container.present?
          run_task_config[:container_overrides] = [
            {
              name: @deploy_job.override_container,
              command: @deploy_job.override_command.split(' ')
            }
          ]
        end

        task_definition_path = @code_manager.task_definition_config_path("config/#{run_task_config[:path]}")
        task_definition = create_task(task_definition_path, run_task_config[:task_overrides], @deploy_job.label)

        push_image(run_task_config[:containers], task_definition, @deploy_job.label)

        options = {
          desired_count: run_task_config[:desired_count],
          group: run_task_config[:group],
          container_overrides: runtime_container_overrides(run_task_config[:container_overrides]),
          network_configuration: run_task_config[:network_configuration]
        }
        options[:launch_type] = run_task_config[:launch_type] if run_task_config[:launch_type].present?
        options[:task_role_arn] = Aws::IAM::Role.new(run_task_config[:task_role]).arn if run_task_config[:task_role]
        options[:task_execution_role_arn] = Aws::IAM::Role.new(run_task_config[:task_execution_role]).arn if run_task_config[:task_execution_role]

        deploy_pre_hook

        run_task_client = Deployer::RunTask::Client.new(@deploy_job, @logger)
        run_task_client.execute(task_definition.task_definition_arn, options)
      end

      def deploy_service
        @logger.info('Start deploy service.')
        ready(:service)

        service_config = @code_manager.deploy_config.find_service(@deploy_job.cluster, @deploy_job.service).deep_dup
        resolve_container_overrides!(service_config)
        merge_container_overrides_into_task_overrides!(service_config)

        task_definition_path = @code_manager.task_definition_config_path("config/#{service_config[:path]}")
        task_definition = create_task(task_definition_path, service_config[:task_overrides], @deploy_job.label)

        push_image(service_config[:containers], task_definition, @deploy_job.label)
        service_client = Deployer::Service::Client.new(@deploy_job, @logger, async_wait: @options[:async_wait])

        raise Exceptions::ValidationError, "Service is not registered. [#{@deploy_job.service}]" unless service_client.exist?

        params = service_config.slice(
          :desired_count,
          :force_new_deployment,
          :health_check_grace_period_seconds,
          :minimum_healthy_percent,
          :maximum_percent
        )

        deploy_pre_hook
        service_client.update(task_definition.task_definition_arn, params)
      end

      def deploy_scheduled_task
        @logger.info('Start deploy scheduled task.')
        ready(:scheduled_task)

        deploy_config = @code_manager.deploy_config
        target_config = deploy_config.find_scheduled_task_target(
          @deploy_job.cluster,
          @deploy_job.scheduled_task_rule,
          @deploy_job.scheduled_task_target
        ).deep_dup
        resolve_container_overrides!(target_config)
        merge_container_overrides_into_task_overrides!(target_config)

        task_definition_path = @code_manager.task_definition_config_path("config/#{target_config[:path]}")
        task_definition = create_task(task_definition_path, target_config[:task_overrides], @deploy_job.label)
        @deploy_job.task_definition_arn = task_definition.task_definition_arn

        push_image(target_config[:containers], task_definition, @deploy_job.label)
        rule_config = deploy_config.find_scheduled_task_rule(@deploy_job.cluster, @deploy_job.scheduled_task_rule)
        deploy_pre_hook

        scheduled_task_client = Ecs::Deployer::ScheduledTask::Client.new(@deploy_job, @logger)
        scheduled_task_client.update(
          rule_config[:rule],
          rule_config[:expression],
          Ecs::Deployer::ScheduledTask::Target.build(@deploy_job, task_definition.task_definition_arn, target_config, @logger),
          {
            enabled: rule_config[:enabled],
            description: rule_config[:description]
          }
        )
      end

      private

      def ready(type)
        @logger.info('Authenticate to ECR.')

        @ecr_client.authenticate
        commit_id = @code_manager.update

        latest_submodule = case type
                           when :run_task
                             @code_manager.deploy_config.find_run_task(@deploy_job.cluster, @deploy_job.run_task)[:latest_submodule]
                           when :service
                             @code_manager.deploy_config.find_service(@deploy_job.cluster, @deploy_job.service)[:latest_submodule]
                           when :scheduled_task
                             @code_manager.deploy_config.find_scheduled_task_rule(@deploy_job.cluster, @deploy_job.scheduled_task_rule)[:latest_submodule]
                           end
        latest_submodule = true if latest_submodule.nil?

        @code_manager.update_submodule(latest_submodule)
        @deploy_job.update_status_provisioning(commit_id)
      end

      def push_image(containers_config, task_definition, tag)
        count = 0
        @deploy_job.docker_build_time = 0

        containers_config.each do |container_config|
          container_definition = task_definition[:container_definitions].find { |container| container[:name] == container_config[:name] }
          raise Exceptions::ValidationError, "#{container_config[:name]} does not exist in task definition." if container_definition.nil?

          repository_name = container_definition[:image].match(%r{/([^:]+)})[1]

          @deploy_job.docker_build_time += @docker_client.build_image(container_config, repository_name)
          @ecr_client.push_image(tag, repository_name)

          count += 1
        end

        raise Exceptions::ValidationError, 'Push image is not found.' if count.zero?

        @deploy_job.save
      end

      def deploy_scheduled_tasks(tag, params); end

      def create_task(task_definition_path, task_overrides, tag)
        task_client = Ecs::Task::Client.new(@logger)

        @task_definitions[task_definition_path] = task_client.register(task_definition_path, task_overrides, tag:) unless @task_definitions.include?(task_definition_path)
        @task_definitions[task_definition_path]
      end

      def deploy_pre_hook
        @deploy_job.reload
        raise Interrupt if @deploy_job.status == DeployJob.status.find_value(:reserved_cancel)

        @deploy_job.update_status_deploying
      end

      def resolve_container_overrides!(config)
        container_overrides_config = config[:container_overrides] || config[:overrides]
        return unless container_overrides_config.present?

        config[:container_overrides] = Ecs::ContainerOverrideBuilder.build(
          container_overrides_config,
          base_dir: deploy_config_base_dir
        )
      end

      def deploy_config_base_dir
        File.expand_path(Pathname(@code_manager.base_path).join('config').to_s)
      end

      def merge_container_overrides_into_task_overrides!(config)
        return if config[:container_overrides].blank?

        task_overrides = (config[:task_overrides] || {}).deep_dup.deep_symbolize_keys
        task_overrides[:container_definitions] = Array(task_overrides[:container_definitions])

        config[:container_overrides].each do |container_override|
          apply_container_override_to_task_overrides!(task_overrides, container_override)
        end

        config[:task_overrides] = task_overrides
      end

      def apply_container_override_to_task_overrides!(task_overrides, container_override)
        override_container_definition = container_override.deep_dup.deep_symbolize_keys.except(:environment_from_files, :secrets_from_files)
        container_definition = task_overrides[:container_definitions].find do |current_container_definition|
          current_container_definition[:name] == override_container_definition[:name]
        end

        if container_definition.present?
          merged_environment = Ecs::NamedEntries.merge(
            container_definition[:environment],
            override_container_definition[:environment]
          )
          merged_secrets = Ecs::NamedEntries.merge(
            container_definition[:secrets],
            override_container_definition[:secrets]
          )
          container_definition.deep_merge!(override_container_definition.except(:environment, :secrets))
          if merged_environment.present?
            container_definition[:environment] = merged_environment
          else
            container_definition.delete(:environment)
          end
          if merged_secrets.present?
            container_definition[:secrets] = merged_secrets
          else
            container_definition.delete(:secrets)
          end
        else
          task_overrides[:container_definitions] << override_container_definition
        end
      end

      def runtime_container_overrides(container_overrides)
        Array(container_overrides).map do |container_override|
          container_override.deep_dup.deep_symbolize_keys.except(:secrets, :secrets_from_files)
        end.reject { |container_override| container_override.except(:name).blank? }
      end
    end
  end
end
