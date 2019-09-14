module Genova
  module Ecs
    module Deployer
      module ScheduledTask
        class Target
          class << self
            attr_accessor  :task_role_arn

            def build_hash(cluster, name, options = {})
              ecs = Aws::ECS::Client.new
              clusters = ecs.describe_clusters(clusters: [cluster]).clusters
              raise Exceptions::ClusterNotFoundError, "Cluster does not eixst. [#{cluster}]" if clusters.count.zero?

              container_overrides = []
              options[:container_overrides].each do |container_override|
                override_environment = container_override[:environment] || []
                container_overrides << override_container(container_override[:name], container_override[:command], override_environment)
              end

              {
                id: name,
                arn: clusters[0].cluster_arn,
                role_arn: options[:cloudwatch_event_iam_role_arn],
                ecs_parameters: {
                  task_definition_arn: options[:task_definition_arn],
                  task_count: options[:desired_count].present? ? options[:desired_count] : 1
                },
                input: {
                  taskRoleArn: options[:task_role_arn],
                  containerOverrides: container_overrides
                }.to_json
              }
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
