module Genova
  module Config
    class DeployConfig < BaseConfig
      def validate!
        schema = File.read(Rails.root.join('lib', 'genova', 'config', 'validator', 'deploy_config.json'))
        errors = JSON::Validator.fully_validate(schema, @params)

        raise ::Genova::Config::DeployConfig::ParseError, errors[0] if errors.size.positive?
      end

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
