module Genova
  module Config
    class DeployConfig < BaseConfig
      def cluster(cluster)
        params = (@params[:clusters] || []).find { |k, _v| k[:name] == cluster }
        raise ParseError, "Cluster parameter is undefined. [#{cluster}]" if params.nil?

        params
      end

      def service(cluster, service)
        services = cluster(cluster)[:services] || {}
        params = services[service.to_sym]

        raise ParseError, "Service parameter is undefined. [#{service}]" if params.nil?

        params
      end

      class ParseError < Error; end
    end
  end
end
