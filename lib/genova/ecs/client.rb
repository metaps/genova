module Genova
  module Ecs
    class Client
      def initialize(cluster, code_manager, options = {})
        @cluster = cluster
        @code_manager = code_manager
        @logger = options[:logger] || ::Logger.new($stdout, level: Settings.logger.level)
        @task_definitions = {}

        @docker_client = Genova::Docker::Client.new(@code_manager, logger: @logger)
        @ecr_client = Genova::Ecr::Client.new(logger: @logger)
        @deploy_config = @code_manager.load_deploy_config
      end

      def ready
        @logger.info('Start sending images to ECR.')

        @ecr_client.authenticate
        @code_manager.update
      end

      def deploy_run_task(run_task, override_container, override_command, tag)
        run_task_config = @deploy_config.find_run_task(@cluster, run_task)

        if override_container.present?
          run_task_config[:container_overrides] = [
            {
              name: override_container,
              command: override_command.split(' ')
            }
          ]
        end

        task_definition_path = @code_manager.task_definition_config_path("config/#{run_task_config[:path]}")
        task_definition = create_task(task_definition_path, run_task_config[:task_overrides], tag)

        push_image(run_task_config[:containers], task_definition, tag)

        options = {
          desired_count: run_task_config[:desired_count],
          group: run_task_config[:group],
          container_overrides: run_task_config[:container_overrides],
          network_configuration: run_task_config[:network_configuration]
        }
        options[:launch_type] = run_task_config[:launch_type] if run_task_config[:launch_type].present?
        options[:task_role_arn] = Aws::IAM::Role.new(run_task_config[:task_role]).arn if run_task_config[:task_role]
        options[:task_execution_role_arn] = Aws::IAM::Role.new(run_task_config[:task_execution_role]).arn if run_task_config[:task_execution_role]

        run_task_client = Deployer::RunTask::Client.new(@cluster, logger: @logger)
        task_arns = run_task_client.execute(task_definition.task_definition_arn, options)

        deploy_response = DeployResponse.new
        deploy_response.task_definition_arn = task_definition.task_definition_arn
        deploy_response.task_arns = task_arns
        deploy_response
      end

      def deploy_service(service, tag)
        service_config = @deploy_config.find_service(@cluster, service)
        cluster_config = @deploy_config.find_cluster(@cluster)

        task_definition_path = @code_manager.task_definition_config_path("config/#{service_config[:path]}")
        task_definition = create_task(task_definition_path, service_config[:task_overrides], tag)

        push_image(service_config[:containers], task_definition, tag)

        service_client = Deployer::Service::Client.new(@cluster, logger: @logger)

        raise Exceptions::ValidationError, "Service is not registered. [#{service}]" unless service_client.exist?(service)

        params = service_config.slice(
          :desired_count,
          :force_new_deployment,
          :health_check_grace_period_seconds,
          :minimum_healthy_percent,
          :maximum_percent
        )

        task_arns = service_client.update(service, task_definition.task_definition_arn, params)

        # `depend_service` will be deprecated in future.
        if cluster_config.include?(:scheduled_tasks)
          cluster_config[:scheduled_tasks].each do |scheduled_task_config|
            scheduled_task_config[:targets].each do |target_config|
              next if target_config[:depend_service] != service

              deploy_scheduled_task(scheduled_task_config[:rule], target_config[:name], tag)
            end
          end
        end

        deploy_response = DeployResponse.new
        deploy_response.task_definition_arn = task_definition.task_definition_arn
        deploy_response.task_arns = task_arns
        deploy_response
      end

      def deploy_scheduled_task(rule, target, tag)
        target_config = @deploy_config.find_scheduled_task_target(@cluster, rule, target)

        task_definition_path = @code_manager.task_definition_config_path("config/#{target_config[:path]}")
        task_definition = create_task(task_definition_path, target_config[:task_overrides], tag)

        push_image(target_config[:containers], task_definition, tag)

        rule_config = @deploy_config.find_scheduled_task_rule(@cluster, rule)

        scheduled_task_client = Ecs::Deployer::ScheduledTask::Client.new(@cluster, logger: @logger)
        scheduled_task_client.update(
          rule_config[:rule],
          rule_config[:expression],
          Ecs::Deployer::ScheduledTask::Target.build(@cluster, task_definition.task_definition_arn, target_config, logger: @logger),
          {
            enabled: rule_config[:enabled],
            description: rule_config[:description]
          }
        )

        deploy_response = DeployResponse.new
        deploy_response.task_definition_arn = task_definition.task_definition_arn
        deploy_response
      end

      private

      def push_image(containers_config, task_definition, tag)
        count = 0

        containers_config.each do |container_config|

          puts container_config
          exit
          container_definition = task_definition[:container_definitions].find { |container| container[:name] == container_config[:name] }
          raise Exceptions::ValidationError, "#{container_config[:name]} does not exist in task definition." if container_definition.nil?

          @ecr_client.push_image(tag, @docker_client.build_image(container_config, container_definition[:image]))
          count += 1
        end

        raise Exceptions::ValidationError, 'Push image is not found.' if count.zero?
      end

      def deploy_scheduled_tasks(tag, params); end

      def create_task(task_definition_path, task_overrides, tag)
        task_client = Ecs::Task::Client.new

        @task_definitions[task_definition_path] = task_client.register(task_definition_path, task_overrides, tag: tag) unless @task_definitions.include?(task_definition_path)
        @task_definitions[task_definition_path]
      end
    end
  end
end
