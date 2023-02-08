module Genova
  module Ecs
    module Deployer
      module ScheduledTask
        class Target
          class << self
            attr_accessor :task_role_arn

            def build(deploy_job, task_definition_arn, target_config, options = {})
              ecs = Aws::ECS::Client.new
              clusters = ecs.describe_clusters(clusters: [deploy_job.cluster]).clusters
              raise Exceptions::NotFoundError, "Cluster does not eixst. [#{deploy_job.cluster}]" if clusters.count.zero?

              logger = options[:logger] || ::Logger.new($stdout, level: Settings.logger.level)
              logger.warn('"task_count" parameter is deprecated. Set variable "desired_count" instead.') if target_config[:task_count].present?
              logger.warn('"overrides" parameter is deprecated. Set variable "container_overrides" instead.') if target_config[:overrides].present?

              container_overrides_config = target_config[:overrides] || target_config[:container_overrides]
              container_overrides = []

              if container_overrides_config.present?
                container_overrides_config.each do |container_override_config|
                  override_environment = container_override_config[:environment] || []
                  container_overrides << override_container(container_override_config[:name], container_override_config[:command], override_environment)
                end
              end

              result = {
                id: target_config[:name],
                arn: clusters[0].cluster_arn,
                role_arn: Aws::IAM::Role.new(target_config[:cloudwatch_event_iam_role] || 'ecsEventsRole').arn,
                ecs_parameters: {
                  task_definition_arn: task_definition_arn,
                  task_count: target_config[:task_count] || target_config[:desired_count] || 1
                },
                input: {
                  containerOverrides: container_overrides
                }
              }
              result[:ecs_parameters][:launch_type] = target_config[:launch_type] if target_config[:launch_type].present?
              result[:ecs_parameters][:network_configuration] = target_config[:network_configuration] if target_config[:network_configuration].present?
              result[:input][:taskRoleArn] = Aws::IAM::Role.new(target_config[:task_role]).arn if target_config[:task_role].present?
              result[:input] = result[:input].to_json
              result
            end

            private

            def override_container(name, command = nil, environments = {})
              environment_overrides = []
              environments.each do |environment|
                environment.each do |env_name, env_value|
                  environment_overrides << {
                    name: env_name,
                    value: env_value
                  }
                end
              end

              container_override = {
                name: name,
                command: command
              }
              container_override[:environment] = environment_overrides if environment_overrides.count.positive?
              container_override
            end
          end
        end
      end
    end
  end
end
