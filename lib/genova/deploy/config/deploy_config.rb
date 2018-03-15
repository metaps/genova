module Genova
  module Deploy
    module Config
      class DeployConfig
        attr_reader :params

        def initialize(account, repository, branch)
          @repository = repository
          @params = Genova::Git::LocalRepositoryManager.new(account, repository, branch).open_deploy_config

          return if @params[:scheduled_tasks].nil?

          # compatibility with deprecated parameters
          @params[:scheduled_tasks].each do |task|
            task[:targets].each do |target|
              if target[:environment].present?
                target[:service] = target[:environment]
                target.delete(:environment)
              end
            end
          end
        end

        def cluster_name(service)
          service_mapping = @params.dig(:service_mappings, service.to_sym)
          return @params[:cluster] if service_mapping.nil?

          if service_mapping.class == String
            cluster = @params[:cluster]
          else
            cluster = service_mapping[:cluster]
            cluster = @params[:cluster] if cluster.nil?
          end

          cluster
        end

        def service_name(service)
          service_mapping = @params.dig(:service_mappings, service.to_sym)
          return service if service_mapping.nil?

          if service_mapping.class == String
            service = service_mapping
          else
            service = service_mapping[:service]
            service = service if service.nil?
          end

          service
        end
      end
    end
  end
end
