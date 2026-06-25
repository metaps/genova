module Genova
  module Ecs
    class ContainerOverrideBuilder
      SUPPORTED_KEYS = %i[name command environment secrets environment_from_files secrets_from_files].freeze
      IGNORED_KEYS = %i[build].freeze

      ENTRY_TYPES = {
        environment: {
          file_key: :environment_from_files,
          file_label: 'environment',
          entry_label: 'environment',
          value_key: :value
        },
        secrets: {
          file_key: :secrets_from_files,
          file_label: 'secrets',
          entry_label: 'secret',
          value_key: :value_from
        }
      }.freeze

      class << self
        def build(container_overrides_config, base_dir:, logger: nil)
          return [] if container_overrides_config.blank?
          raise Exceptions::ValidationError, "'container_overrides' must be an array." unless container_overrides_config.is_a?(Array)

          container_overrides_config.map do |container_override_config|
            build_container_override(container_override_config, base_dir, logger)
          end
        end

        private

        def build_container_override(container_override_config, base_dir, logger)
          raise Exceptions::ValidationError, "Each entry in 'container_overrides' must be a hash. [#{container_override_config.inspect}]" unless container_override_config.is_a?(Hash)

          container_override = container_override_config.deep_dup.deep_symbolize_keys
          container_identifier = container_override[:name] || '(unknown)'
          warn_and_remove_build_key!(container_override, container_identifier, logger)
          validate_supported_keys!(container_override, container_identifier)
          ENTRY_TYPES.each_key do |entry_type|
            assign_named_entries!(container_override, entry_type, base_dir, container_identifier)
          end

          container_override
        end

        def warn_and_remove_build_key!(container_override, container_identifier, logger)
          return unless (container_override.keys & IGNORED_KEYS).include?(:build)

          logger&.warn("Ignore 'build' key in container override '#{container_identifier}'.")
          container_override.delete(:build)
        end

        def validate_supported_keys!(container_override, container_identifier)
          unsupported_keys = container_override.keys - SUPPORTED_KEYS
          return if unsupported_keys.empty?

          raise Exceptions::ValidationError,
                "Unsupported keys in container override '#{container_identifier}'. [#{unsupported_keys.sort.join(', ')}]"
        end

        def assign_named_entries!(container_override, entry_type, base_dir, container_identifier)
          entries = resolve_named_entries(container_override, entry_type, base_dir, container_identifier)

          if entries.present?
            container_override[entry_type] = entries
          else
            container_override.delete(entry_type)
          end
        end

        def resolve_named_entries(container_override, entry_type, base_dir, container_identifier)
          entry_options = ENTRY_TYPES.fetch(entry_type)
          file_entries = Ecs::NamedEntries.load_from_files!(
            container_override.delete(entry_options[:file_key]),
            base_dir:,
            container_identifier:,
            file_label: entry_options[:file_label],
            entry_label: entry_options[:entry_label],
            value_key: entry_options[:value_key]
          )
          inline_entries = Ecs::NamedEntries.normalize(
            container_override[entry_type],
            value_key: entry_options[:value_key],
            entry_label: entry_options[:entry_label],
            container_identifier:
          )

          Ecs::NamedEntries.merge(file_entries, inline_entries)
        end
      end
    end
  end
end
