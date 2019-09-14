module Genova
  module Ecs
    module Deployer
      module Service
        class Client
          LOG_SEPARATOR = '-' * 96

          attr_accessor :wait_timeout, :polling_interval

          def initialize(cluster, logger)
            @cluster = cluster
            @logger = logger

            @ecs = Aws::ECS::Client.new
            @task = Ecs::Task::Client.new

            @wait_timeout = 900
            @polling_interval = 20
          end

          def update(service, task_definition = nil, wait = true)
            task_definition = @task.register_clone(@cluster, service) if task_definition.nil?
            result = @ecs.update_service(
              cluster: @cluster,
              service: service,
              task_definition: task_definition[:family] + ':' + task_definition[:revision].to_s
            )

            wait_for_deploy(service, result.service.task_definition) if wait
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
                status_logs << "  #{task[:task_definition_arn]} [#{task[:last_status]}]"
              end
            end

            {
              current_task_count: current_task_count,
              new_registerd_task_count: new_registerd_task_count,
              status_logs: status_logs
            }
          end

          def wait_for_deploy(service, task_definition_arn)
            raise Exceptions::ServiceNotFoundError, "'#{service}' service is not found." unless exist?(service)

            wait_time = 0
            @logger.info 'Start deployment.'

            result = @ecs.describe_services(
              cluster: @cluster,
              services: [service]
            )
            desired_count = result[:services][0][:desired_count]

            loop do
              sleep(@polling_interval)
              wait_time += @polling_interval
              result = deploy_status(service, task_definition_arn)

              @logger.info "Updating... [#{result[:new_registerd_task_count]}/#{desired_count}] (#{wait_time} seconds elapsed)"
              @logger.info "New task: #{task_definition_arn}"
              @logger.info LOG_SEPARATOR

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

                if wait_time > @wait_timeout
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
