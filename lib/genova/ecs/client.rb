module Genova
  module Ecs
    class Client
      def initialize(cluster, repository_manager, options = {})
        @cluster = cluster
        @repository_manager = repository_manager
        @logger = options[:logger] || ::Logger.new(nil)
        @task_definitions = {}

        @deploy_client = EcsDeployer::Client.new(
          @cluster,
          @logger
        )
        @docker_client = Genova::Docker::Client.new(@repository_manager, logger: @logger)
        @ecs_client = Aws::ECS::Client.new
        @ecr_client = Genova::Ecr::Client.new(logger: @logger)
        @deploy_config = @repository_manager.load_deploy_config
      end

      def ready
        @ecr_client.authenticate
        @repository_manager.update
      end

      def deploy_run_task(run_task, tag)
        run_task_config = @deploy_config.run_task(@cluster, run_task)

        deploy(run_task_config[:containers], run_task_config[:path], tag)
        task_definition_path = @repository_manager.task_definition_config_path('config/' + run_task_config[:path])
        task_definition = create_task(task_definition_path, tag)

        options = {
          cluster: @cluster,
          task_definition: task_definition.task_definition_arn
        }
        options.merge!(run_task_config[:ecs_configuration] || {})

        run_task_response = @ecs_client.run_task(options)
        run_task_definition_arns = run_task_response[:tasks].map{ |key| key[:task_definition_arn] }

        {
          run_task_definition_arns: run_task_definition_arns
        }
      end

      def deploy_service(service, tag)
        service_config = @deploy_config.service(@cluster, service)
        cluster_config = @deploy_config.cluster(@cluster)

        deploy(service_config[:containers], service_config[:path], tag)

        service_task_definition_path = @repository_manager.task_definition_config_path('config/' + service_config[:path])
        service_task_definition = create_task(service_task_definition_path, tag)

        service_client = @deploy_client.service

        raise Genova::Config::ValidationError, "Service is not registered. [#{service}]" unless service_client.exist?(service)

        service_client.wait_timeout = Settings.deploy.wait_timeout
        service_client.update(service, service_task_definition)

        scheduled_task_definition_arns = []
        scheduled_task_definition_arns = deploy_scheduled_tasks(tag, depend_service: service) if cluster_config.include?(:scheduled_tasks)

        {
          service_task_definition_arn: service_task_definition.task_definition_arn,
          scheduled_task_definition_arns: scheduled_task_definition_arns
        }
      end

      def deploy_scheduled_task(rule, target, tag)
        deploy_scheduled_tasks(tag, rule: rule, target: target)
        {
          scheduled_task_definition_arns: deploy_scheduled_tasks(tag, rule: rule, target: target)
        }
      end

      private

      def deploy(containers_config, path, tag)
        count = 0

        containers_config.each do |container_config|
          repository_name = @docker_client.build_image(container_config, path)
          @ecr_client.push_image(tag, repository_name)

          count += 1
        end

        raise Genova::Config::ValidationError, 'Push image is not found.' if count.zero?
      end

      def deploy_scheduled_tasks(tag, options)
        task_definition_arns = []

        cluster_config = @deploy_config.cluster(@cluster)
        cluster_config[:scheduled_tasks].each do |scheduled_task|
          scheduled_task_client = @deploy_client.scheduled_task
          config_base_path = Pathname(@repository_manager.base_path).join('config').to_s
          targets = []
          targets_arns = []

          next if options[:rule].present? && scheduled_task[:rule] != options[:rule]

          scheduled_task[:targets].each do |target|
            next if options[:depend_service].present? && target[:depend_service] != options[:depend_service]
            next if options[:target].present? && target[:name] != options[:target]

            deploy(target[:containers], target[:path], tag) if options[:target].present?

            task_definition_path = File.expand_path(target[:path], config_base_path)
            task_definition = create_task(task_definition_path, tag)
            task_definition_arn = task_definition.task_definition_arn
            targets_arns << {
              target: target[:name],
              task_definition_arn: task_definition_arn
            }

            builder = scheduled_task_client.target_builder(target[:name])

            cloudwatch_event_role = target[:cloudwatch_event_role] || 'ecsEventsRole'
            builder.cloudwatch_event_role_arn = Aws::IAM::Role.new(cloudwatch_event_role).arn

            builder.task_definition_arn = task_definition_arn
            builder.task_role_arn = Aws::IAM::Role.new(target[:task_role]).arn if target.include?(:task_role)
            builder.task_count = target[:task_count] || 1

            if target.include?(:overrides)
              target[:overrides].each do |override|
                override_environment = override[:environment] || []
                builder.override_container(override[:name], override[:command], override_environment)
              end
            end

            targets << builder.to_hash
          end

          next if targets.size.zero?

          task_definition_arns << {
            rule: scheduled_task[:rule],
            targets_arns: targets_arns
          }

          @logger.info("Update '#{scheduled_task[:rule]}' rule.")

          scheduled_task_client.update(
            scheduled_task[:rule],
            scheduled_task[:expression],
            targets,
            description: scheduled_task[:description]
          )
        end

        raise Genova::Config::ValidationError, 'Scheduled task target or rule is undefined.' if options[:rule].present? && task_definition_arns.count.zero?

        task_definition_arns
      end

      def create_task(task_definition_path, tag)
        task_client = EcsDeployer::Task::Client.new
        @task_definitions[task_definition_path] = task_client.register(task_definition_path, tag: tag) unless @task_definitions.include?(task_definition_path)

        @task_definitions[task_definition_path]
      end
    end
  end
end
