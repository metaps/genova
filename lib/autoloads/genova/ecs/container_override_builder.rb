module Genova
  module Ecs
    class ContainerOverrideBuilder
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
        def build(container_overrides_config, base_dir:)
          return [] if container_overrides_config.blank?
          raise Exceptions::ValidationError, "'container_overrides' must be an array." unless container_overrides_config.is_a?(Array)

          container_overrides_config.map do |container_override_config|
            build_container_override(container_override_config, base_dir)
          end
        end

        private

        def build_container_override(container_override_config, base_dir)
          raise Exceptions::ValidationError, "Each entry in 'container_overrides' must be a hash. [#{container_override_config.inspect}]" unless container_override_config.is_a?(Hash)

          container_override = container_override_config.deep_dup.deep_symbolize_keys
          container_identifier = container_override[:name] || '(unknown)'
          ENTRY_TYPES.each_key do |entry_type|
            assign_named_entries!(container_override, entry_type, base_dir, container_identifier)
          end

          container_override
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
