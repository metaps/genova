module Genova
  module Ecs
    module Deployer
      module RunTask
        class Client
          LOG_SEPARATOR = '-' * 96

          def initialize(cluster, logger)
            @cluster = cluster
            @logger = logger
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
            task_arns = results[:tasks].map { |key| key[:task_arn] }

            wait(task_arns)
            results[:tasks].map { |key| key[:task_definition_arn] }
          end

          private

          def wait(task_arns)
            wait_time = 0

            @logger.info 'Start task.'
            @logger.info LOG_SEPARATOR

            loop do
              pending = false
              exit_task_arns = []

              describe_tasks = @ecs_client.describe_tasks(cluster: @cluster, tasks: task_arns)
              describe_tasks[:tasks].each do |task|
                sleep(Settings.deploy.polling_interval)
                wait_time += Settings.deploy.polling_interval

                @logger.info "Waiting for execution result... (#{wait_time}s elapsed)"
                @logger.info LOG_SEPARATOR

                if task[:last_status] == 'PENDING'
                  pending = true

                  raise Exceptions::DeployTimeoutError, "Process is timed out. (Task ARN: #{task[:task_arn]})" if wait_time > Settings.deploy.wait_timeout

                elsif !exit_task_arns.include?(task[:task_arn])
                  task[:containers].each do |container|
                    @logger.info 'Container'
                    @logger.info "  Name: #{container[:name]}"
                    @logger.info "  Exit code: #{container[:exit_code]}"
                    @logger.info "  Reason: #{container[:reason]}"
                    @logger.info LOG_SEPARATOR
                  end

                  @logger.info "Task ARN: #{task[:task_arn]}"
                  @logger.info "Stopped reason: #{task[:stopped_reason]}"
                  @logger.info LOG_SEPARATOR

                  exit_task_arns << task[:task_arn]
                end
              end

              break unless pending
            end
          end
        end
      end
    end
  end
end
