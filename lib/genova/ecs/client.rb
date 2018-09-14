module Genova
  module Ecs
    class Client
      def initialize(cluster, repository_manager, options = {})
        @cluster = cluster
        @repository_manager = repository_manager
        @logger = options[:logger] || ::Logger.new(STDOUT)
        @task_definitions = {}

        @deploy_client = EcsDeployer::Client.new(
          @cluster,
          @logger
        )
        @docker_client = Genova::Docker::Client.new(@repository_manager, logger: @logger)
        @ecs_client = Aws::ECS::Client.new
        @ecr_client = Genova::Ecr::Client.new(logger: @logger)
      end

      def ready
        @ecr_client.authenticate
        @repository_manager.update
      end

      def deploy_service(service, image_tag)
        deploy_config = @repository_manager.load_deploy_config
        service_config = deploy_config.service(@cluster, service)

        raise Genova::Config::DeployConfigError, 'You need to specify :path parameter in deploy.yml' if service_config[:path].nil?

        repository_names = @docker_client.build_images(service_config[:containers], service_config[:path])
        pushed_size = 0

        repository_names.each do |repository_name|
          @ecr_client.push_image(image_tag, repository_name)
          pushed_size += 1
        end

        raise ImagePushError, 'Push image is not found.' if pushed_size.zero?

        service_task_definition_path = @repository_manager.task_definition_config_path(service_config[:path])
        service_task_definition = create_task(@deploy_client.task, service_task_definition_path, image_tag)

        service_client = @deploy_client.service
        cluster_config = @repository_manager.load_deploy_config.cluster(@cluster)

        unless service_client.exist?(service)
          formation_config = cluster_config[:services][service.to_sym][:formation]
          raise Genova::Config::DeployConfigError, "Service is not registered. [#{service}]" if formation_config.nil?

          create_service(service, service_task_definition, formation_config)
        end

        service_client.wait_timeout = Settings.deploy.wait_timeout
        service_client.update(service, service_task_definition)

        scheduled_task_definition_arns = deploy_scheduled_tasks(service, image_tag) if cluster_config.include?(:scheduled_tasks)

        @ecr_client.destroy_images(repository_names)

        {
          service_task_definition_arn: service_task_definition.task_definition_arn,
          scheduled_task_definition_arns: scheduled_task_definition_arns
        }
      end

      def deploy_scheduled_tasks(depend_service, image_tag)
        task_definition_arns = []

        cluster_config = @repository_manager.load_deploy_config.cluster(@cluster)
        cluster_config[:scheduled_tasks].each do |scheduled_task|
          task_client = @deploy_client.task
          scheduled_task_client = @deploy_client.scheduled_task
          config_base_path = Pathname(@repository_manager.base_path).join('config').to_s
          targets = []
          targets_arns = []

          scheduled_task[:targets].each do |target|
            next unless target[:depend_service] == depend_service

            task_definition_path = File.expand_path(target[:path], config_base_path)
            task_definition = create_task(task_client, task_definition_path, image_tag)
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

          task_definition_arns << {
            rule: scheduled_task[:rule],
            targets_arns: targets_arns
          }

          return @logger.info("'#{depend_service}' target is not registered yet.") if targets.count.zero?

          @logger.info("Update '#{scheduled_task[:rule]}' rule.")

          scheduled_task_client.update(
            scheduled_task[:rule],
            scheduled_task[:expression],
            targets,
            description: scheduled_task[:description]
          )
        end

        task_definition_arns
      end

      private

      def create_service(service, task_definition, formation_config)
        formation_config[:cluster] = @cluster
        formation_config[:service_name] = service
        formation_config[:task_definition] = task_definition.task_definition_arn

        @ecs_client.create_service(formation_config)

        nil
      end

      def create_task(task_client, task_definition_path, image_tag)
        unless @task_definitions.include?(task_definition_path)
          @task_definitions[task_definition_path] = task_client.register(task_definition_path, tag: image_tag)
        end

        @task_definitions[task_definition_path]
      end
    end
  end
end
