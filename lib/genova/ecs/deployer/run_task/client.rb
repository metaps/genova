module Genova
  module Ecs
    module Deployer
      module RunTask
        class Client
          def initialize(cluster)
            @cluster = cluster
          end

          def execute(task_definition_arn, options = {})
            options[:cluster] = @cluster
            options[:task_definition] = task_definition_arn
            ecs_client = Aws::ECS::Client.new

            results = ecs_client.run_task(options)
            results[:tasks].map { |key| key[:task_definition_arn] }
          end
        end
      end
    end
  end
end
