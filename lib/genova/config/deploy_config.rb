module Genova
  module Config
    class DeployConfig < BaseConfig
      def validate!
        schema = File.read(Rails.root.join('lib', 'genova', 'config', 'validator', 'deploy_config.json'))
        errors = JSON::Validator.fully_validate(schema, @params)

        raise Exceptions::ValidationError, errors[0] if errors.size.positive?
      end

      def cluster(cluster)
        values = (@params[:clusters] || []).find { |k| k[:name] == cluster }
        raise Exceptions::ValidationError, "Cluster is undefined. [#{cluster}]" if values.nil?

        values
      end

      def run_task(cluster, run_task)
        run_tasks = cluster(cluster)[:run_tasks] || {}
        values = run_tasks[run_task.to_sym]

        raise Exceptions::ValidationError, "Run task is undefined. [#{run_task}]" if values.nil?

        values
      end

      def service(cluster, service)
        services = cluster(cluster)[:services] || {}
        values = services[service.to_sym]

        raise Exceptions::ValidationError, "Service is undefined. [#{service}]" if values.nil?

        values
      end

      def target(target)
        values = (@params[:targets] || []).find { |k| k[:name] == target }
        raise Exceptions::ValidationError, "Target is undefined. [#{target}]" if values.nil?

        values
      end
    end
  end
end
