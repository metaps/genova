module Genova
  module Config
    class DeployConfig < BaseConfig
      def validate!
        schema = File.read(Rails.root.join('lib/autoloads/genova/config/validator/deploy_config.json'))
        errors = JSON::Validator.fully_validate(schema, @params)

        raise Exceptions::ValidationError, errors[0] if errors.size.positive?
      end

      def find_cluster(cluster)
        clusters = @params[:clusters] || []
        result = clusters.find { |k| k[:name] == cluster }

        raise Exceptions::ValidationError, "Cluster is undefined. [#{cluster}]" if result.nil?

        result
      end

      def find_run_task(cluster, run_task)
        run_tasks = find_cluster(cluster)[:run_tasks] || {}
        result = run_tasks[run_task.to_sym]

        raise Exceptions::ValidationError, "Run task is undefined. [#{cluster}/#{run_task}]" if result.nil?

        result
      end

      def find_service(cluster, service)
        services = find_cluster(cluster)[:services] || {}
        result = services[service.to_sym]

        raise Exceptions::ValidationError, "Service is undefined. [#{cluster}/#{service}]" if result.nil?

        result
      end

      def find_scheduled_task_rule(cluster, rule)
        scheduled_tasks = find_cluster(cluster)[:scheduled_tasks] || []
        result = scheduled_tasks.find { |k| k[:rule] == rule }

        raise Exceptions::ValidationError, "Scheduled task rule is undefined. [#{cluster}/#{rule}]" if result.nil?

        result
      end

      def find_scheduled_task_target(cluster, rule, target)
        rule = find_scheduled_task_rule(cluster, rule)
        result = rule[:targets].find { |k| k[:name] == target }

        raise Exceptions::ValidationError, "Scheduled task target is undefined. [#{cluster}/#{rule}/#{target}]" unless result

        result
      end

      def find_target(target)
        targets = @params[:targets] || []
        result = targets.find { |k| k[:name] == target }

        raise Exceptions::ValidationError, "Target is undefined. [#{target}]" if result.nil?

        result
      end
    end
  end
end
