module Genova
  module Ecs
    module NamedEntries
      module_function

      CONTAINER_ENTRY_KEYS = %i[environment secrets].freeze

      def merge_container_entries(base_definition, override_definition)
        CONTAINER_ENTRY_KEYS.each_with_object({}) do |entry_key, merged|
          next unless override_definition[entry_key].present?

          merged[entry_key] = merge(base_definition[entry_key], override_definition[entry_key])
        end
      end

      def assign_container_entries!(container_definition, named_entries)
        named_entries.each do |entry_key, entries|
          if entries.present?
            container_definition[entry_key] = entries
          else
            container_definition.delete(entry_key)
          end
        end
      end

      def merge(base_entries, override_entries)
        result = Array(base_entries).deep_dup

        Array(override_entries).each do |entry|
          result.delete_if { |current_entry| current_entry[:name] == entry[:name] }
          result << entry
        end

        result
      end

      def normalize(entries, value_key:, entry_label:, container_identifier: nil, value_transform: method(:stringify_value))
        Array(entries).each_with_object([]) do |entry, normalized|
          unless entry.is_a?(Hash)
            raise Exceptions::ValidationError, invalid_entry_message(entry_label, entry, container_identifier)
          end

          entry_hash = entry.deep_symbolize_keys
          if entry_hash.keys.sort == [:name, value_key].sort
            normalized << build_entry(entry_hash[:name], entry_hash[value_key], value_key:, value_transform:)
            next
          end

          entry_hash.each do |entry_name, entry_value|
            normalized << build_entry(entry_name, entry_value, value_key:, value_transform:)
          end
        end
      end

      def load_from_files!(
        file_paths,
        base_dir:,
        container_identifier:,
        file_label:,
        entry_label:,
        value_key:,
        value_transform: method(:stringify_value)
      )
        Array(file_paths).each_with_object([]) do |file_path, entries|
          unless file_path.is_a?(String) && file_path.present?
            raise Exceptions::ValidationError,
                  "Invalid #{file_label} file path for container override '#{container_identifier}'. [#{file_path.inspect}]"
          end

          resolved_path = File.expand_path(file_path, base_dir)
          current_entries = read_file(
            resolved_path,
            file_label:,
            entry_label:,
            value_key:,
            value_transform:
          )
          entries.replace(merge(entries, current_entries))
        end
      end

      def read_file(path, file_label:, entry_label:, value_key:, value_transform: method(:stringify_value))
        raise Exceptions::ValidationError, "#{file_label.capitalize} file does not exist. [#{path}]" unless File.file?(path)

        case File.extname(path)
        when '.yml', '.yaml'
          parse_yaml_file(path, file_label:, entry_label:, value_key:, value_transform:)
        when '.env', '.dotenv'
          parse_dotenv_file(path, file_label:, value_key:, value_transform:)
        else
          raise Exceptions::ValidationError, "Unsupported #{file_label} file extension: #{File.extname(path)} [#{path}]"
        end
      end

      def parse_yaml_file(path, file_label:, entry_label:, value_key:, value_transform: method(:stringify_value))
        yaml = YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [:name, value_key], aliases: false)

        case yaml
        when Hash
          yaml.map { |name, value| build_entry(name, value, value_key:, value_transform:) }
        when Array
          yaml.map do |entry|
            has_string_keys = entry.is_a?(Hash) && entry.key?('name') && entry.key?(value_key.to_s)
            has_symbol_keys = entry.is_a?(Hash) && entry.key?(:name) && entry.key?(value_key)
            raise Exceptions::ValidationError, "Invalid #{entry_label} entry. [#{path}]" unless has_string_keys || has_symbol_keys

            build_entry(
              entry.key?('name') ? entry['name'] : entry[:name],
              entry.key?(value_key.to_s) ? entry[value_key.to_s] : entry[value_key],
              value_key:,
              value_transform:
            )
          end
        else
          raise Exceptions::ValidationError, "#{file_label.capitalize} file must be a hash or array. [#{path}]"
        end
      end

      def parse_dotenv_file(path, file_label:, value_key:, value_transform: method(:stringify_value))
        File.read(path).each_line.each_with_object([]) do |line, entries|
          line = line.strip
          next if line.blank? || line.start_with?('#')

          name, value = line.split('=', 2)
          name = name.strip
          raise Exceptions::ValidationError, "Invalid #{file_label} line. [#{path}]" if name.blank?

          entries << build_entry(name, strip_wrapping_quotes(value.to_s.strip), value_key:, value_transform:)
        end
      end

      def stringify_value(value)
        value.is_a?(String) ? value : value.to_s
      end

      def build_entry(name, value, value_key:, value_transform:)
        {
          name: name.to_s,
          value_key => value_transform.call(value)
        }
      end
      private_class_method :build_entry

      def invalid_entry_message(entry_label, entry, container_identifier)
        if container_identifier.present?
          "Invalid #{entry_label} entry for container override '#{container_identifier}'. [#{entry.inspect}]"
        else
          "Invalid #{entry_label} entry. [#{entry.inspect}]"
        end
      end
      private_class_method :invalid_entry_message

      def strip_wrapping_quotes(value)
        return value unless value.length >= 2
        return value[1..-2] if value.start_with?('"') && value.end_with?('"')
        return value[1..-2] if value.start_with?("'") && value.end_with?("'")

        value
      end
      private_class_method :strip_wrapping_quotes
    end
  end
end
