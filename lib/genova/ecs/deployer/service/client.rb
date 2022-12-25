module Genova
  module Ecs
    module Deployer
      module Service
        class Client
          def initialize(deploy_job, options = {})
            @deploy_job = deploy_job
            @logger = options[:logger] || ::Logger.new($stdout, level: Settings.logger.level)
            @async_wait = options[:async_wait]
            @ecs = Aws::ECS::Client.new
          end

          def update(task_definition_arn, options = {})
            @logger.info('Update service task.')

            params = {
              cluster: @deploy_job.cluster,
              service: @deploy_job.service,
              task_definition: task_definition_arn
            }

            params.merge(options.slice(:desired_count, :force_new_deployment, :health_check_grace_period_seconds))

            deployment_config = options.slice(:minimum_healthy_percent, :maximum_percent)
            params[:deployment_configuration] = deployment_config if deployment_config.count.positive?

            result = @ecs.update_service(params)

            @deploy_job.task_definition_arn = result.service.task_definition
            @deploy_job.save

            if @async_wait
              @logger.info('Monitor ECR service update status in asynchronous mode.')
              ::Ecs::ServiceProvisioningWorker.perform_async(@deploy_job.id)
            else
              @logger.info('Monitor ECR service update status in synchronous mode.')
              @logger.info('You can stop monitoring by pressing Ctrl+C.') if @deploy_job.mode == DeployJob.mode.find_value(:manual)
              ::Ecs::ServiceProvisioningWorker.new.perform(@deploy_job.id)
            end
          end

          def exist?
            status = nil
            result = @ecs.describe_services(
              cluster: @deploy_job.cluster,
              services: [@deploy_job.service]
            )
            result[:services].each do |svc|
              next unless svc[:service_name] == @deploy_job.service && svc[:status] == 'ACTIVE'

              status = svc
              break
            end

            status.nil? ? false : true
          end
        end
      end
    end
  end
end
