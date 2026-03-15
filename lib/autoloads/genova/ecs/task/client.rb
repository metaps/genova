require 'deep_merge/rails_compat'

module Genova
  module Ecs
    module Task
      class Client
        def initialize(logger)
          @ecs_client = Aws::ECS::Client.new
          @cipher = Genova::Utils::Cipher.new(logger)
          @logger = logger
        end

        def register(path, task_overrides = {}, params = {})
          raise IOError, "File does not exist. [#{path}]" unless File.file?(path)

          yaml = YAML.unsafe_load(File.read(path))
          task_definition = Oj.load(Oj.dump(yaml), symbol_keys: true)
          load_environment_from_files!(task_definition, path)
          merge_task_parameters!(task_definition, task_overrides) if task_overrides.present?

          replace_parameter_variables!(task_definition, params)
          decrypt_environment_variables!(task_definition)

          task_definition[:tags] = [] if task_definition[:tags].nil?
          task_definition[:tags] << { key: 'genova.version', value: Version::STRING }
          task_definition[:tags] << { key: 'genova.build', value: params[:tag] }

          result = @ecs_client.register_task_definition(task_definition)

          @logger.info("Task created. [#{result[:task_definition][:task_definition_arn]}]")

          result[:task_definition]
        end

        private

        def merge_task_parameters!(task_definition, task_overrides)
          # https://github.com/metaps/genova/issues/291
          task_definition.deep_merge!(task_overrides.except(:container_definitions))

          # Parameters consisting of arrays initialize the parent side of the merge.
          # https://github.com/metaps/genova/issues/283
          reset_array!(task_definition, task_overrides, :requires_compatibilities)

          override_container_definitions!(task_definition, task_overrides)

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

        def override_container_definitions!(task_definition, task_overrides)
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

            merge_container_environment!(container_definition, override_container_definition)
            container_definition.deeper_merge!(override_container_definition)
          end
        end

        def merge_container_environment!(container_definition, override_container_definition)
          return unless container_definition[:environment].present? && override_container_definition[:environment].present?

          override_container_definition[:environment].each do |environment|
            container_definition[:environment].delete_if { |k, _v| k[:name] == environment[:name] }
          end
        end

        def load_environment_from_files!(task_definition, task_definition_path)
          raise Exceptions::TaskDefinitionValidationError, '\'container_definitions\' is undefined.' unless task_definition.key?(:container_definitions)
          unless task_definition[:container_definitions].is_a?(Array)
            raise Exceptions::TaskDefinitionValidationError, '\'container_definitions\' must be an array.'
          end

          base_dir = Pathname(task_definition_path).dirname

          task_definition[:container_definitions].each do |container_definition|
            unless container_definition.is_a?(Hash)
              raise Exceptions::TaskDefinitionValidationError, 'Each entry in \'container_definitions\' must be a hash.'
            end

            load_container_environment_from_files!(container_definition, base_dir)
          end
        end

        def load_container_environment_from_files!(container_definition, base_dir)
          environment_file_paths = Array(container_definition.delete(:environment_from_files)).compact
          return if environment_file_paths.empty?

          file_environments = environment_file_paths.each_with_object([]) do |environment_file_path, environments|
            resolved_path = File.expand_path(environment_file_path, base_dir)
            current_environments = read_environment_file(resolved_path)
            merge_container_environment!({ environment: environments }, { environment: current_environments })
            environments.concat(current_environments)
          end

          container_definition[:environment] ||= []
          merge_container_environment!({ environment: file_environments }, container_definition)
          container_definition[:environment] = file_environments + container_definition[:environment]
        end

        def read_environment_file(path)
          raise Exceptions::TaskDefinitionValidationError, "Environment file does not exist. [#{path}]" unless File.file?(path)

          case File.extname(path)
          when '.yml', '.yaml'
            parse_yaml_environment_file(path)
          else
            parse_dotenv_environment_file(path)
          end
        end

        def parse_yaml_environment_file(path)
          yaml = YAML.unsafe_load(File.read(path))

          case yaml
          when Hash
            yaml.map { |name, value| { name: name.to_s, value: value } }
          when Array
            yaml.map do |environment|
              has_string_keys = environment.is_a?(Hash) && environment.key?('name') && environment.key?('value')
              has_symbol_keys = environment.is_a?(Hash) && environment.key?(:name) && environment.key?(:value)
              raise Exceptions::TaskDefinitionValidationError, "Invalid environment entry. [#{path}]" unless has_string_keys || has_symbol_keys

              {
                name: environment.key?('name') ? environment['name'] : environment[:name],
                value: environment.key?('value') ? environment['value'] : environment[:value]
              }
            end
          else
            raise Exceptions::TaskDefinitionValidationError, "Environment file must be a hash or array. [#{path}]"
          end
        end

        def parse_dotenv_environment_file(path)
          environments = []

          File.read(path).each_line do |line|
            line = line.strip
            next if line.blank? || line.start_with?('#')

            name, value = line.split('=', 2)
            raise Exceptions::TaskDefinitionValidationError, "Invalid environment line. [#{path}]" if name.blank?

            environments << { name: name, value: value.to_s }
          end

          environments
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
