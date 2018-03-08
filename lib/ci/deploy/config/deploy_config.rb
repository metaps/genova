module CI
  module Deploy
    module Config
      class DeployConfig
        attr_reader :params

        def initialize(account, repository, branch)
          @repository = repository
          @params = CI::Github::Client.new(account, repository, branch).fetch_deploy_config
        end

        def cluster_name(environment)
          service_mapping = @params.dig(:service_mappings, environment.to_sym)
          return @params[:cluster] if service_mapping.nil?

          if service_mapping.class == String
            cluster = @params[:cluster]
          else
            cluster = service_mapping[:cluster]
            cluster = @params[:cluster] if cluster.nil?
          end

          cluster
        end

        def service_name(environment)
          service_mapping = @params.dig(:service_mappings, environment.to_sym)
          return environment if service_mapping.nil?

          if service_mapping.class == String
            service = service_mapping
          else
            service = service_mapping[:service]
            service = environment if service.nil?
          end

          service
        end
      end
    end
  end
end
