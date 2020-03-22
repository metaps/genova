module Genova
  module Ecs
    module Deployer
      module Service
        class Client
          LOG_SEPARATOR = '-' * 96

          def initialize(cluster, logger)
            @cluster = cluster
            @logger = logger

            @ecs = Aws::ECS::Client.new
            @task = Genova::Ecs::Task::Client.new
          end

          def update(service, task_definition_arn, options = {}, wait = true)
            params = {
              cluster: @cluster,
              service: service,
              task_definition: task_definition_arn
            }

            params.merge(options.slice(:desired_count, :force_new_deployment, :health_check_grace_period_seconds))

            deployment_config = options.slice(:minimum_healthy_percent, :maximum_percent)
            params[:deployment_configuration] = deployment_config if deployment_config.count.positive?

            result = @ecs.update_service(params)

            wait(service, result.service.task_definition) if wait
            result.service
          end

          def exist?(service)
            status = nil
            result = @ecs.describe_services(
              cluster: @cluster,
              services: [service]
            )
            result[:services].each do |svc|
              next unless svc[:service_name] == service && svc[:status] == 'ACTIVE'

              status = svc
              break
            end

            status.nil? ? false : true
          end

          private

          def detect_stopped_task(service, task_definition_arn)
            stopped_tasks = @ecs.list_tasks(
              cluster: @cluster,
              service_name: service,
              desired_status: 'STOPPED'
            ).task_arns

            return if stopped_tasks.size.zero?

            description_tasks = @ecs.describe_tasks(
              cluster: @cluster,
              tasks: stopped_tasks
            ).tasks

            description_tasks.each do |task|
              raise Exceptions::TaskStoppedError, task.stopped_reason if task.task_definition_arn == task_definition_arn
            end
          end

          def deploy_status(service, task_definition_arn)
            detect_stopped_task(service, task_definition_arn)

            # Get current tasks
            result = @ecs.list_tasks(
              cluster: @cluster,
              service_name: service,
              desired_status: 'RUNNING'
            )

            new_registerd_task_count = 0
            current_task_count = 0
            status_logs = []

            if result[:task_arns].size.positive?
              status_logs << 'Current services:'

              result = @ecs.describe_tasks(
                cluster: @cluster,
                tasks: result[:task_arns]
              )

              result[:tasks].each do |task|
                if task_definition_arn == task[:task_definition_arn]
                  new_registerd_task_count += 1 if task[:last_status] == 'RUNNING'
                else
                  current_task_count += 1
                end

                status_logs << "- Task ARN: #{task[:task_arn]}"
                status_logs << "  Task definition ARN: #{task[:task_definition_arn]} [#{task[:last_status]}]"
              end
            end

            {
              current_task_count: current_task_count,
              new_registerd_task_count: new_registerd_task_count,
              status_logs: status_logs
            }
          end

          def wait(service, task_definition_arn)
            raise Exceptions::ServiceNotFoundError, "'#{service}' service is not found." unless exist?(service)

            wait_time = 0

            @logger.info 'Start deployment.'
            @logger.info LOG_SEPARATOR

            result = @ecs.describe_services(
              cluster: @cluster,
              services: [service]
            )
            desired_count = result[:services][0][:desired_count]

            loop do
              sleep(Settings.deploy.polling_interval)
              wait_time += Settings.deploy.polling_interval
              result = deploy_status(service, task_definition_arn)

              @logger.info "Deploying service... [#{result[:new_registerd_task_count]}/#{desired_count}] (#{wait_time}s elapsed)"
              @logger.info "New task: #{task_definition_arn}"

              if result[:status_logs].count.positive?
                result[:status_logs].each do |log|
                  @logger.info log
                end

                @logger.info LOG_SEPARATOR
              end

              if result[:new_registerd_task_count] == desired_count && result[:current_task_count].zero?
                @logger.info "Service update succeeded. [#{result[:new_registerd_task_count]}/#{desired_count}]"
                @logger.info "New task definition: #{task_definition_arn}"

                break
              else
                @logger.info 'You can stop process with Ctrl+C. Deployment continues in background.'

                if wait_time > Settings.deploy.wait_timeout
                  @logger.info "New task definition: #{task_definition_arn}"
                  raise Exceptions::DeployTimeoutError, 'Service is being updating, but process is timed out.'
                end
              end
            end
          end
        end
      end
    end
  end
end
