module Genova
  module Ecs
    module Deployer
      module RunTask
        class Client
          def initialize(cluster)
            @cluster = cluster
            @ecs_client = Aws::ECS::Client.new
          end

          def execute(task_definition_arn, params = {})
            options = {}
            options[:cluster] = @cluster
            options[:task_definition] = task_definition_arn
            options[:count] = params[:desired_count].present? ? params[:desired_count] : 1

            options[:overrides] = {}
            options[:overrides][:container_overrides] = params[:container_overrides] if params[:container_overrides].present?

            results = @ecs_client.run_task(options)
            results[:tasks].map { |key| key[:task_definition_arn] }
          end
        end
      end
    end
  end
end
