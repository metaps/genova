module Genova
  module Ecs
    module Deployer
      module RunTask
        class Client
          LOG_SEPARATOR = '-' * 96

          def initialize(deploy_job, options = {})
            @deploy_job = deploy_job
            @logger = options[:logger] || ::Logger.new($stdout, level: Settings.logger.level)
            @ecs_client = Aws::ECS::Client.new
          end

          def execute(task_definition_arn, params = {})
            @logger.info('Execute run task.')

            options = {}
            options[:launch_type] = params[:launch_type]
            options[:cluster] = @deploy_job.cluster
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
                message += "#{failure[:reason]} occurred and execution failed. [#{failure[:arn]}]"
              end

              raise Exceptions::RunTaskError, message
            end

            task_arns = results[:tasks].map { |key| key[:task_arn] }
            wait(task_arns)

            @deploy_job.update_status_complate(
              task_definition_arn: task_definition_arn,
              task_arns: task_arns
            )

            Genova::Deploy::Runner.finished(@deploy_job, @logger)
          end

          private

          def wait(task_arns)
            @logger.info('Wait for the Run task execution to complete.')
            @logger.info(task_arns.join(', '))
            @logger.info(LOG_SEPARATOR)

            wait_time = 0
            stopped_tasks = []

            loop do
              describe_tasks = @ecs_client.describe_tasks(cluster: @deploy_job.cluster, tasks: task_arns)
              run_task_size = describe_tasks[:tasks].size

              describe_tasks[:tasks].each do |task|
                raise Exceptions::DeployTimeoutError, "Monitoring run task, timeout reached. [#{task[:task_arn]}]" if wait_time > Settings.ecs.wait_timeout

                sleep(Settings.ecs.polling_interval)
                wait_time += Settings.ecs.polling_interval

                @logger.info("Waiting for run task execution... (#{wait_time}s elapsed)")
                @logger.info(LOG_SEPARATOR)
                @logger.info("#{task[:task_arn]} [#{task[:last_status]}]")

                next unless task[:last_status] == 'STOPPED' && !stopped_tasks.include?(task[:task_arn])

                stopped_tasks << task[:task_arn]
                @logger.info("Stopped reason: #{task[:stopped_reason]}")

                task[:containers].each do |container|
                  next if container[:exit_code].zero?

                  @logger.warn("Error detected in container exit status. [#{container[:name]}]")
                end
              end

              break if run_task_size == stopped_tasks.size
            end

            @logger.info('All run tasks have been completed.')
          end
        end
      end
    end
  end
end
