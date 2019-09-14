module Genova
  module Ecs
    class Client
      def initialize(cluster, code_manager, options = {})
        @cluster = cluster
        @code_manager = code_manager
        @logger = options[:logger] || ::Logger.new(nil)
        @task_definitions = {}

        @docker_client = Genova::Docker::Client.new(@code_manager, logger: @logger)
        @ecr_client = Ecr::Client.new(logger: @logger)
        @deploy_config = @code_manager.load_deploy_config
      end

      def ready
        @logger.info('Start sending images to ECR.')

        @ecr_client.authenticate
        @code_manager.pull
      end

      def deploy_run_task(run_task, tag)
        run_task_config = @deploy_config.run_task(@cluster, run_task)

        build(run_task_config[:containers], run_task_config[:path], tag)
        task_definition_path = @code_manager.task_definition_config_path('config/' + run_task_config[:path])
        task_definition = create_task(task_definition_path, tag)

        options = run_task_config[:ecs_configuration] || {}

        run_task_client = Ecs::Deployer::RunTask::Client.new(@cluster)
        run_task_client.execute(task_definition.task_definition_arn, options)
      end

      def deploy_service(service, tag)
        service_config = @deploy_config.service(@cluster, service)
        cluster_config = @deploy_config.cluster(@cluster)

        build(service_config[:containers], service_config[:path], tag)

        service_task_definition_path = @code_manager.task_definition_config_path('config/' + service_config[:path])
        service_task_definition = create_task(service_task_definition_path, tag)

        service_client = Ecs::Deployer::Service::Client.new(@cluster, @logger)

        raise Exceptions::ValidationError, "Service is not registered. [#{service}]" unless service_client.exist?(service)

        task_definition_arn = service_task_definition.task_definition_arn
        params = service_config.slice(
          :desired_count,
          :force_new_deployment,
          :health_check_grace_period_seconds,
          :minimum_healthy_percent,
          :maximum_percent
        )
        params[:task_definition] = task_definition_arn

        service_client.wait_timeout = Settings.deploy.wait_timeout
        service_client.update(service, params)

        deploy_scheduled_tasks(tag, depend_service: service) if cluster_config.include?(:scheduled_tasks)

        task_definition_arn
      end

      def deploy_scheduled_task(rule, target, tag)
        deploy_scheduled_tasks(tag, rule: rule, target: target)
      end

      private

      def build(containers_config, path, tag)
        count = 0

        containers_config.each do |container_config|
          @ecr_client.push_image(tag, @docker_client.build_image(container_config, path))
          count += 1
        end

        raise Exceptions::ValidationError, 'Push image is not found.' if count.zero?
      end

      def deploy_scheduled_tasks(tag, options)
        task_definition_arns = []

        cluster_config = @deploy_config.cluster(@cluster)
        cluster_config[:scheduled_tasks].each do |scheduled_task|
          scheduled_task_client = Ecs::Deployer::ScheduledTask::Client.new(@cluster)
          config_base_path = Pathname(@code_manager.base_path).join('config').to_s
          targets = []

          next if options[:rule].present? && scheduled_task[:rule] != options[:rule]

          scheduled_task[:targets].each do |target|
            next if options[:depend_service].present? && target[:depend_service] != options[:depend_service]
            next if options[:target].present? && target[:name] != options[:target]

            build(target[:containers], target[:path], tag) if options[:target].present?

            task_definition_path = File.expand_path(target[:path], config_base_path)
            task_definition = create_task(task_definition_path, tag)

            cloudwatch_event_role = target[:cloudwatch_event_role] || 'ecsEventsRole'

            builder = Ecs::Deployer::ScheduledTask::Target.new(@cluster, target[:name])
            builder.cloudwatch_event_role_arn = Aws::IAM::Role.new(cloudwatch_event_role).arn

            builder.task_definition_arn = task_definition.task_definition_arn
            builder.task_role_arn = Aws::IAM::Role.new(target[:task_role]).arn if target.include?(:task_role)
            builder.task_count = target[:task_count] || 1

            if target.include?(:overrides)
              target[:overrides].each do |override|
                override_environment = override[:environment] || []
                builder.override_container(override[:name], override[:command], override_environment)
              end
            end

            targets << builder.to_hash
            task_definition_arns << task_definition.task_definition_arn
          end

          next if targets.size.zero?

          @logger.info("Update '#{scheduled_task[:rule]}' rule.")

          scheduled_task_client.update(
            scheduled_task[:rule],
            scheduled_task[:expression],
            targets,
            description: scheduled_task[:description]
          )
        end

        raise Exceptions::ValidationError, 'Scheduled task target or rule is undefined.' if options[:rule].present? && task_definition_arns.count.zero?

        task_definition_arns
      end

      def create_task(task_definition_path, tag)
        task_client = Ecs::Task::Client.new
        @task_definitions[task_definition_path] = task_client.register(task_definition_path, tag: tag) unless @task_definitions.include?(task_definition_path)

        @task_definitions[task_definition_path]
      end
    end
  end
end
