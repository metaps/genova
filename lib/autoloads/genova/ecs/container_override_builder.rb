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
          file_secrets = load_secrets_from_files!(
            container_override.delete(:secrets_from_files),
            base_dir,
            container_identifier
          )
          inline_secrets = normalize_secrets(container_override[:secrets], container_identifier)
          merged_secrets = merge_secrets(file_secrets, inline_secrets)

          if merged_environments.present?
            container_override[:environment] = merged_environments
          else
            container_override.delete(:environment)
          end

          if merged_secrets.present?
            container_override[:secrets] = merged_secrets
          else
            container_override.delete(:secrets)
          end

          container_override
        end

        def load_environment_from_files!(environment_file_paths, base_dir, container_identifier)
          Array(environment_file_paths).each_with_object([]) do |environment_file_path, environments|
            unless environment_file_path.is_a?(String) && environment_file_path.present?
              raise Exceptions::ValidationError,
                    "Invalid environment file path for container override '#{container_identifier}'. [#{environment_file_path.inspect}]"
            end

            resolved_path = File.expand_path(environment_file_path, base_dir)
            current_environments = read_environment_file(resolved_path)
            environments.replace(merge_environments(environments, current_environments))
          end
        end

        def load_secrets_from_files!(secret_file_paths, base_dir, container_identifier)
          Array(secret_file_paths).each_with_object([]) do |secret_file_path, secrets|
            unless secret_file_path.is_a?(String) && secret_file_path.present?
              raise Exceptions::ValidationError,
                    "Invalid secrets file path for container override '#{container_identifier}'. [#{secret_file_path.inspect}]"
            end

            resolved_path = File.expand_path(secret_file_path, base_dir)
            current_secrets = read_secrets_file(resolved_path)
            secrets.replace(merge_secrets(secrets, current_secrets))
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

        def normalize_secrets(secrets, container_identifier)
          Array(secrets).each_with_object([]) do |secret, normalized|
            unless secret.is_a?(Hash)
              raise Exceptions::ValidationError,
                    "Invalid secret entry for container override '#{container_identifier}'. [#{secret.inspect}]"
            end

            secret_hash = secret.deep_symbolize_keys
            if secret_hash.keys.sort == %i[name value_from]
              normalized << {
                name: secret_hash[:name].to_s,
                value_from: normalize_secret_value(secret_hash[:value_from])
              }
              next
            end

            secret_hash.each do |secret_name, secret_value|
              normalized << {
                name: secret_name.to_s,
                value_from: normalize_secret_value(secret_value)
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

        def merge_secrets(base_secrets, override_secrets)
          merged_secrets = base_secrets.deep_dup

          override_secrets.each do |secret|
            merged_secrets.delete_if { |current_secret| current_secret[:name] == secret[:name] }
            merged_secrets << secret
          end

          merged_secrets
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

        def read_secrets_file(path)
          raise Exceptions::ValidationError, "Secrets file does not exist. [#{path}]" unless File.file?(path)

          case File.extname(path)
          when '.yml', '.yaml'
            parse_yaml_secrets_file(path)
          when '.env', '.dotenv'
            parse_dotenv_secrets_file(path)
          else
            raise Exceptions::ValidationError, "Unsupported secrets file extension: #{File.extname(path)} [#{path}]"
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

        def parse_yaml_secrets_file(path)
          yaml = YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: %i[name value_from], aliases: false)

          case yaml
          when Hash
            yaml.map { |name, value_from| { name: name.to_s, value_from: normalize_secret_value(value_from) } }
          when Array
            yaml.map do |secret|
              has_string_keys = secret.is_a?(Hash) && secret.key?('name') && secret.key?('value_from')
              has_symbol_keys = secret.is_a?(Hash) && secret.key?(:name) && secret.key?(:value_from)
              raise Exceptions::ValidationError, "Invalid secrets entry. [#{path}]" unless has_string_keys || has_symbol_keys

              {
                name: secret.key?('name') ? secret['name'].to_s : secret[:name].to_s,
                value_from: normalize_secret_value(secret.key?('value_from') ? secret['value_from'] : secret[:value_from])
              }
            end
          else
            raise Exceptions::ValidationError, "Secrets file must be a hash or array. [#{path}]"
          end
        end

        def parse_dotenv_environment_file(path)
          File.read(path).each_line.each_with_object([]) do |line, environments|
            line = line.strip
            next if line.blank? || line.start_with?('#')

            name, value = line.split('=', 2)
            name = name.strip
            raise Exceptions::ValidationError, "Invalid environment line. [#{path}]" if name.blank?

            value = value.to_s.strip
            value = value[1..-2] if value.length >= 2 && ((value.start_with?('"') && value.end_with?('"')) || (value.start_with?("'") && value.end_with?("'")))

            environments << { name:, value: }
          end
        end

        def parse_dotenv_secrets_file(path)
          File.read(path).each_line.each_with_object([]) do |line, secrets|
            line = line.strip
            next if line.blank? || line.start_with?('#')

            name, value_from = line.split('=', 2)
            name = name.strip
            raise Exceptions::ValidationError, "Invalid secrets line. [#{path}]" if name.blank?

            value_from = value_from.to_s.strip
            value_from = value_from[1..-2] if value_from.length >= 2 && ((value_from.start_with?('"') && value_from.end_with?('"')) || (value_from.start_with?("'") && value_from.end_with?("'")))

            secrets << { name:, value_from: normalize_secret_value(value_from) }
          end
        end

        def normalize_environment_value(value)
          value.is_a?(String) ? value : value.to_s
        end

        def normalize_secret_value(value)
          value.is_a?(String) ? value : value.to_s
        end
      end
    end
  end
end
