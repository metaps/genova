module Ecs
  class ServiceProvisioningWorker
    LOG_SEPARATOR = '-' * 96

    include Sidekiq::Worker

    sidekiq_options queue: :ecs_service_provisioning, retry: false

    def perform(id)
      @deploy_job = DeployJob.find(id)
      @ecs_client = Aws::ECS::Client.new

      @logger = Genova::Logger::MongodbLogger.new(@deploy_job)
      @logger.info('Start monitoring.')
      @logger.info(LOG_SEPARATOR)

      begin
        wait_for_task_replacement
      rescue => e
        @logger.error('Error during deployment.')
        @logger.error(e.message)
        @logger.error(e.backtrace.join("\n")) if e.backtrace.present?

        @deploy_job.update_status_failure
      end
    end

    private

    def wait_for_task_replacement
      wait_time = 0
      desired_count = @ecs_client.describe_services(
        cluster: @deploy_job.cluster,
        services: [@deploy_job.service]
      )[:services][0][:desired_count]

      loop do
        sleep(Settings.ecs.polling_interval)
        wait_time += Settings.ecs.polling_interval
        response = retrieve_status(@deploy_job.task_definition_arn)

        @logger.info("Service is being updated... [#{response[:new_registerd_task_count]}/#{desired_count}] (#{wait_time}s elapsed)")
        @logger.info("New task: #{@deploy_job.task_definition_arn}")

        if response[:status_logs].count.positive?
          response[:status_logs].each do |log|
            @logger.info(log)
          end

          @logger.info(LOG_SEPARATOR)
        end

        if response[:new_registerd_task_count] == desired_count && response[:current_task_count].zero?
          @logger.info("All tasks have been replaced. [#{response[:new_registerd_task_count]}/#{desired_count}]")
          @logger.info("New task definition [#{@deploy_job.task_definition_arn}]")

          @deploy_job.update_status_complate(task_arns: response[:task_arns])
          break

        elsif wait_time > Settings.ecs.wait_timeout
          @logger.info("New task definition [#{@deploy_job.task_definition_arn}]")
          raise Genova::Exceptions::DeployTimeoutError, 'Monitoring service changes, timeout reached.'
        end
      end
    end

    def detect_stopped_task(task_definition_arn)
      stopped_tasks = @ecs_client.list_tasks(
        cluster: @deploy_job.cluster,
        service_name: @deploy_job.service,
        desired_status: 'STOPPED'
      )[:task_arns]

      return if stopped_tasks.size.zero?

      description_tasks = @ecs_client.describe_tasks(
        cluster: @deploy_job.cluster,
        tasks: stopped_tasks
      )[:tasks]

      description_tasks.each do |task|
        raise Genova::Exceptions::TaskStoppedError, task[:stopped_reason] if task[:task_definition_arn] == task_definition_arn
      end
    end

    def retrieve_status(task_definition_arn)
      detect_stopped_task(task_definition_arn)

      # Get current tasks.
      response = @ecs_client.list_tasks(
        cluster: @deploy_job.cluster,
        service_name: @deploy_job.service,
        desired_status: 'RUNNING'
      )

      new_registerd_task_count = 0
      current_task_count = 0
      status_logs = []

      if response[:task_arns].size.positive?
        status_logs << 'Current services:'

        tasks = @ecs_client.describe_tasks(
          cluster: @deploy_job.cluster,
          tasks: response[:task_arns]
        )

        tasks[:tasks].each do |task|
          if task_definition_arn == task[:task_definition_arn]
            new_registerd_task_count += 1 if task[:last_status] == 'RUNNING'
          else
            current_task_count += 1
          end

          status_logs << "- Task ARN: #{task[:task_arn]}"
          status_logs << "  Task definition ARN: #{task[:task_definition_arn]} [#{task[:last_status]}]"
        end
      else
        status_logs << 'All old tasks have been stopped. Wait for a new task to start.'
      end

      {
        current_task_count: current_task_count,
        new_registerd_task_count: new_registerd_task_count,
        status_logs: status_logs,
        task_arns: response[:task_arns]
      }
    end
  end
end
