module Genova
  module Ecs
    class Client
      def initialize(cluster, repository_manager, options = {})
        @cluster = cluster
        @repository_manager = repository_manager

        @ecs = Aws::ECS::Client.new(profile: options[:profile], region: options[:region])
        @logger = options[:logger] || ::Logger.new(STDOUT)
        @deployer_client = EcsDeployer::Client.new(
          cluster,
          @logger,
          profile: options[:profile],
          region: options[:region]
        )
        @task_definitions = {}
      end

      def deploy_service(service, tag_revision)
        task_definition_path = @repository_manager.task_definition_config_path(service)
        task_definition = create_task(@deployer_client.task, task_definition_path, tag_revision)

        service_client = @deployer_client.service
        cluster_config = @repository_manager.load_deploy_config.cluster(@cluster)

        unless service_client.exist?(service)
          formation_config = cluster_config[:services][service.to_sym][:formation]
          raise Genova::Config::DeployConfigError, "Service is not registered. [#{service}]" if formation_config.nil?

          create_service(service, task_definition, formation_config)
        end

        service_client.wait_timeout = Settings.deploy.wait_timeout
        service_client.update(service, task_definition)

        task_definition
      end

      def deploy_scheduled_tasks(depend_service, tag_revision)
        cluster_config = @repository_manager.load_deploy_config.cluster(@cluster)
        cluster_config[:scheduled_tasks].each do |scheduled_task|
          task_client = @deployer_client.task
          scheduled_task_client = @deployer_client.scheduled_task
          config_base_path = Pathname(@repository_manager.path).join('config').to_s
          targets = []

          scheduled_task[:targets].each do |target|
            next unless target[:depend_service] == depend_service

            task_definition_path = File.expand_path(target[:path], config_base_path)
            task_definition = create_task(task_client, task_definition_path, tag_revision)

            builder = scheduled_task_client.target_builder(target[:name])
            builder.role(target[:role]) if target.include?(:target)
            builder.task_definition_arn = task_definition.task_definition_arn
            builder.task_role(target[:task_role]) if target.include?(:task_role)
            builder.task_count = target[:task_count] || 1

            if target.include?(:overrides)
              target[:overrides].each do |override|
                override_environment = override[:environment] || []
                builder.override_container(override[:name], override[:command], override_environment)
              end
            end

            targets << builder.to_hash
          end

          return @logger.info("'#{depend_service}' target is not registered yet.") if targets.count.zero?

          @logger.info("Update '#{scheduled_task[:rule]}' rule.")

          scheduled_task_client.update(
            scheduled_task[:rule],
            scheduled_task[:expression],
            targets,
            description: scheduled_task[:description]
          )
        end
      end

      private

      def create_service(service, task_definition, formation_config)
        formation_config[:cluster] = @cluster
        formation_config[:service_name] = service
        formation_config[:task_definition] = task_definition.task_definition_arn

        @ecs.create_service(formation_config)

        nil
      end

      def create_task(task_client, task_definition_path, tag_revision)
        unless @task_definitions.include?(task_definition_path)
          @task_definitions[task_definition_path] = task_client.register(task_definition_path, tag: tag_revision)
        end

        @task_definitions[task_definition_path]
      end
    end
  end
end
