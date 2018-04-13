module Genova
  module Config
    class DeployConfig < BaseConfig
      def cluster(cluster)
        params = (@params[:clusters] || []).find { |k, _v| k[:name] == cluster }
        raise DeployConfigError, "Cluster is undefined. [#{cluster}]" if params.nil?

        params
      end

      def service(cluster, service)
        services = cluster(cluster)[:services] || {}
        params = services[service.to_sym]

        raise DeployConfigError, "Service is undefined. [#{service}]" if params.nil?
        params
      end
    end

    class DeployConfigError < Error; end
  end
end
