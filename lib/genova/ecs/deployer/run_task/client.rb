module Genova
  module Ecs
    module Deployer
      module RunTask
        class Client
          LOG_SEPARATOR = '-' * 96

          def initialize(cluster, options = {})
            @cluster = cluster
            @logger = options[:logger] || ::Logger.new($stdout, level: Settings.logger.level)
            @ecs_client = Aws::ECS::Client.new
          end

          def execute(task_definition_arn, params = {})
            options = {}
            options[:launch_type] = params[:launch_type]
            options[:cluster] = @cluster
            options[:task_definition] = task_definition_arn
            options[:count] = params[:desired_count].present? ? params[:desired_count] : 1
            options[:group] = params[:group]
            options[:network_configuration] = params[:network_configuration]
            options[:overrides] = {
              container_overrides: params[:container_overrides],
              task_role_arn: params[:task_role_arn],
              execution_role_arn: params[:task_execution_role_arn]
            }

            results = @ecs_client.run_task(options)

            if results[:failures].present?
              message = ''
              results[:failures].each do |failure|
                message += "#{failure[:reason]} occurred and execution failed. (#{failure[:arn]})"
              end

              raise Exceptions::RunTaskError, message
            end

            task_arns = results[:tasks].map { |key| key[:task_arn] }

            wait(task_arns)
            task_arns
          end

          private

          def wait(task_arns)
            wait_time = 0

            @logger.info('Start tasks.')
            @logger.info(task_arns)
            @logger.info(LOG_SEPARATOR)

            stopped_tasks = []

            loop do
              describe_tasks = @ecs_client.describe_tasks(cluster: @cluster, tasks: task_arns)
              run_task_size = describe_tasks[:tasks].size

              describe_tasks[:tasks].each do |task|
                raise Exceptions::DeployTimeoutError, "Process is timed out. (Task ARN: #{task[:task_arn]})" if wait_time > Settings.deploy.wait_timeout

                sleep(Settings.deploy.polling_interval)
                wait_time += Settings.deploy.polling_interval

                @logger.info("Waiting for execution result... (#{wait_time}s elapsed)")
                @logger.info(LOG_SEPARATOR)

                next unless task[:last_status] == 'STOPPED' && !stopped_tasks.include?(task[:task_arn])

                stopped_tasks << task[:task_arn]

                @logger.info('Run task has finished.')
                @logger.info(JSON.pretty_generate(task.to_h))
              end

              break if run_task_size == stopped_tasks.size
            end
          end
        end
      end
    end
  end
end
