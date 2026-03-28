module Genova
  module Ecs
    module Deployer
      module ScheduledTask
        class Target
          class << self
            attr_accessor :task_role_arn

            def build(deploy_job, task_definition_arn, target_config, logger)
              logger.warn('"task_count" parameter is deprecated. Set variable "desired_count" instead.') if target_config[:task_count].present?
              logger.warn('"overrides" parameter is deprecated. Set variable "container_overrides" instead.') if target_config[:overrides].present?

              ecs = Aws::ECS::Client.new(logger:)
              clusters = ecs.describe_clusters(clusters: [deploy_job.cluster]).clusters
              raise Exceptions::NotFoundError, "Cluster does not eixst. [#{deploy_job.cluster}]" if clusters.count.zero?

              container_overrides_config = target_config[:container_overrides] || target_config[:overrides]
              container_overrides = []

              if container_overrides_config.present?
                container_overrides_config.each do |container_override_config|
                  container_override = override_container(container_override_config)
                  container_overrides << container_override if container_override.present?
                end
              end

              result = {
                id: target_config[:name],
                arn: clusters[0].cluster_arn,
                role_arn: Aws::IAM::Role.new(target_config[:cloudwatch_event_iam_role] || 'ecsEventsRole').arn,
                ecs_parameters: {
                  task_definition_arn:,
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

            def override_container(container_override_config)
              container_override = container_override_config.deep_dup.deep_symbolize_keys.except(:environment_from_files, :secrets_from_files, :secrets)
              environment_overrides = Ecs::NamedEntries.normalize(
                container_override[:environment],
                value_key: :value,
                entry_label: 'environment'
              )
              container_override[:environment] = environment_overrides if environment_overrides.count.positive?
              container_override.delete(:environment) if environment_overrides.empty?
              return if container_override.except(:name).blank?

              container_override
            end
          end
        end
      end
    end
  end
end
