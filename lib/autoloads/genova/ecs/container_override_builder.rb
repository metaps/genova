module Genova
  module Ecs
    class ContainerOverrideBuilder
      class << self
        def build(container_overrides_config, base_dir:)
          return [] if container_overrides_config.blank?
          raise Exceptions::ValidationError, "'container_overrides' must be an array." unless container_overrides_config.is_a?(Array)

          container_overrides_config.map do |container_override_config|
            build_container_override(container_override_config, base_dir)
          end
        end

        private

        def build_container_override(container_override_config, base_dir)
          unless container_override_config.is_a?(Hash)
            raise Exceptions::ValidationError, "Each entry in 'container_overrides' must be a hash. [#{container_override_config.inspect}]"
          end

          container_override = container_override_config.deep_dup.deep_symbolize_keys
          container_identifier = container_override[:name] || '(unknown)'

          file_environments = load_environment_from_files!(
            container_override.delete(:environment_from_files),
            base_dir,
            container_identifier
          )
          inline_environments = normalize_environments(container_override[:environment], container_identifier)
          merged_environments = merge_environments(file_environments, inline_environments)

          if merged_environments.present?
            container_override[:environment] = merged_environments
          else
            container_override.delete(:environment)
          end

          container_override
        end

        def load_environment_from_files!(environment_file_paths, base_dir, container_identifier)
          Array(environment_file_paths).each_with_object([]) do |environment_file_path, environments|
            resolved_environment_file_path = environment_file_path.respond_to?(:to_str) ? environment_file_path.to_str : environment_file_path
            unless resolved_environment_file_path.is_a?(String) && resolved_environment_file_path.present?
              raise Exceptions::ValidationError,
                    "Invalid environment file path for container override '#{container_identifier}'. [#{environment_file_path.inspect}]"
            end

            resolved_path = File.expand_path(resolved_environment_file_path, base_dir)
            current_environments = read_environment_file(resolved_path)
            environments.replace(merge_environments(environments, current_environments))
          end
        end

        def normalize_environments(environments, container_identifier)
          Array(environments).each_with_object([]) do |environment, normalized|
            unless environment.is_a?(Hash)
              raise Exceptions::ValidationError,
                    "Invalid environment entry for container override '#{container_identifier}'. [#{environment.inspect}]"
            end

            env_hash = environment.deep_symbolize_keys
            if env_hash.keys.sort == %i[name value]
              normalized << {
                name: env_hash[:name].to_s,
                value: normalize_environment_value(env_hash[:value])
              }
              next
            end

            env_hash.each do |env_name, env_value|
              normalized << {
                name: env_name.to_s,
                value: normalize_environment_value(env_value)
              }
            end
          end
        end

        def merge_environments(base_environments, override_environments)
          merged_environments = base_environments.deep_dup

          override_environments.each do |environment|
            merged_environments.delete_if { |current_environment| current_environment[:name] == environment[:name] }
            merged_environments << environment
          end

          merged_environments
        end

        def read_environment_file(path)
          raise Exceptions::ValidationError, "Environment file does not exist. [#{path}]" unless File.file?(path)

          case File.extname(path)
          when '.yml', '.yaml'
            parse_yaml_environment_file(path)
          when '.env', '.dotenv'
            parse_dotenv_environment_file(path)
          else
            raise Exceptions::ValidationError, "Unsupported environment file extension: #{File.extname(path)} [#{path}]"
          end
        end

        def parse_yaml_environment_file(path)
          yaml = YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: %i[name value], aliases: false)

          case yaml
          when Hash
            yaml.map { |name, value| { name: name.to_s, value: normalize_environment_value(value) } }
          when Array
            yaml.map do |environment|
              has_string_keys = environment.is_a?(Hash) && environment.key?('name') && environment.key?('value')
              has_symbol_keys = environment.is_a?(Hash) && environment.key?(:name) && environment.key?(:value)
              raise Exceptions::ValidationError, "Invalid environment entry. [#{path}]" unless has_string_keys || has_symbol_keys

              {
                name: environment.key?('name') ? environment['name'].to_s : environment[:name].to_s,
                value: normalize_environment_value(environment.key?('value') ? environment['value'] : environment[:value])
              }
            end
          else
            raise Exceptions::ValidationError, "Environment file must be a hash or array. [#{path}]"
          end
        end

        def parse_dotenv_environment_file(path)
          File.read(path).each_line.each_with_object([]) do |line, environments|
            line = line.strip
            next if line.blank? || line.start_with?('#')

            name, value = line.split('=', 2)
            raise Exceptions::ValidationError, "Invalid environment line. [#{path}]" if name.blank?

            environments << { name:, value: value.to_s }
          end
        end

        def normalize_environment_value(value)
          value.is_a?(String) ? value : value.to_s
        end
      end
    end
  end
end
