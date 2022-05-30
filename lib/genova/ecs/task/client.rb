require 'deep_merge/rails_compat'

module Genova
  module Ecs
    module Task
      class Client
        def initialize
          @ecs_client = Aws::ECS::Client.new
          @cipher = Genova::Utils::Cipher.new
        end

        def register(path, task_overrides = {}, params = {})
          raise IOError, "File does not exist. [#{path}]" unless File.file?(path)

          yaml = YAML.load(File.read(path))
          task_definition = Oj.load(Oj.dump(yaml), symbol_keys: true)
          merge_task_parameters!(task_definition, task_overrides) if task_overrides.present?

          replace_parameter_variables!(task_definition, params)
          decrypt_environment_variables!(task_definition)

          task_definition[:tags] = [] if task_definition[:tags].nil?
          task_definition[:tags] << { key: 'genova.version', value: Version::STRING }
          task_definition[:tags] << { key: 'genova.build', value: params[:tag] }

          result = @ecs_client.register_task_definition(task_definition)
          result[:task_definition]
        end

        private

        def merge_task_parameters!(task_definition, task_overrides)
          # https://github.com/metaps/genova/issues/291
          task_definition.deep_merge!(task_overrides.except(:container_definitions))

          # Parameters consisting of arrays initialize the parent side of the merge.
          # https://github.com/metaps/genova/issues/283
          reset_array!(task_definition, task_overrides, :requires_compatibilities)

          (task_overrides[:container_definitions] || []).each_with_index do |override_container_definition, index|
            container_definition = task_definition[:container_definitions].find { |k, _v| k[:name] == override_container_definition[:name] }

            next unless container_definition.present?

            reset_array!(task_definition, task_overrides, :container_definitions, index, :command)
            reset_array!(task_definition, task_overrides, :container_definitions, index, :entry_point)
            reset_array!(task_definition, task_overrides, :container_definitions, index, :links)
            reset_array!(task_definition, task_overrides, :container_definitions, index, :dns_servers)
            reset_array!(task_definition, task_overrides, :container_definitions, index, :dns_search_domains)
            reset_array!(task_definition, task_overrides, :container_definitions, index, :default_security_options)
            reset_array!(task_definition, task_overrides, :container_definitions, index, :health_check, :command)
            reset_array!(task_definition, task_overrides, :container_definitions, index, :linux_parameters, :capabilities, :add)
            reset_array!(task_definition, task_overrides, :container_definitions, index, :linux_parameters, :capabilities, :drop)

            container_definition.deeper_merge!(override_container_definition)
          end

          task_definition
        end

        def reset_array!(task_definition, task_overrides, *params)
          return unless task_definition.dig(*params).present?
          return unless task_overrides.dig(*params).present?

          if params.size > 1
            value = task_definition.dig(*params[0..params.size - 2])
            value[params[params.size - 1]] = []
          else
            task_definition[params[0]] = []
          end
        end

        def replace_parameter_variables!(variables, params = {})
          variables.each do |variable|
            if variable.instance_of?(Array) || variable.instance_of?(Hash)
              replace_parameter_variables!(variable, params)
            elsif variable.instance_of?(String)
              params.each do |replace_key, replace_value|
                variable.gsub!("{{#{replace_key}}}", replace_value)
              end
            end
          end
        end

        def decrypt_environment_variables!(task_definition)
          raise Exceptions::TaskDefinitionValidationError, '\'container_definitions\' is undefined.' unless task_definition.key?(:container_definitions)

          task_definition[:container_definitions].each do |container_definition|
            next unless container_definition.key?(:environment)

            container_definition[:environment].each do |environment|
              if environment[:value].instance_of?(String)
                environment[:value] = @cipher.decrypt(environment[:value]) if @cipher.encrypt_format?(environment[:value])
              else
                # https://github.com/naomichi-y/ecs_deployer/issues/6
                environment[:value] = environment[:value].to_s
              end
            end
          end
        end
      end
    end
  end
end
