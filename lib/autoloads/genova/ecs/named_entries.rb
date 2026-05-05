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
          raise Exceptions::ValidationError, invalid_entry_message(entry_label, entry, container_identifier) unless entry.is_a?(Hash)

          entry_hash = entry.deep_symbolize_keys
          canonical_keys = %i[name value value_from]

          if (entry_hash.keys & canonical_keys).any?
            raise Exceptions::ValidationError, invalid_entry_message(entry_label, entry, container_identifier) unless entry_hash.keys.sort == [:name, value_key].sort

            normalized << build_entry(entry_hash[:name], entry_hash[value_key], value_key:, value_transform:)
            next
          end

          entry_hash.each do |entry_name, entry_value|
            normalized << build_entry(entry_name, entry_value, value_key:, value_transform:)
          end
        end
      end

      def load_from_files!(file_paths, options = {})
        base_dir = options.fetch(:base_dir)
        container_identifier = options.fetch(:container_identifier)
        file_label = options.fetch(:file_label)
        entry_label = options.fetch(:entry_label)
        value_key = options.fetch(:value_key)
        value_transform = options.fetch(:value_transform, method(:stringify_value))

        Array(file_paths).each_with_object([]) do |file_path, entries|
          unless file_path.is_a?(String) && file_path.present?
            raise Exceptions::ValidationError,
                  "Invalid #{file_label} file path for container override '#{container_identifier}'. [#{file_path.inspect}]"
          end

          resolved_path = File.expand_path(file_path, base_dir)
          validate_within_base_dir!(resolved_path, base_dir, file_label, container_identifier)
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
            raise Exceptions::ValidationError, "Invalid #{entry_label} entry. [#{path}]" unless valid_yaml_array_entry?(entry, value_key)

            entry_hash = entry.deep_symbolize_keys
            build_entry(
              entry_hash[:name],
              entry_hash[value_key],
              value_key:,
              value_transform:
            )
          end
        else
          raise Exceptions::ValidationError, "#{file_label.capitalize} file must be a hash or array. [#{path}]"
        end
      end

      def valid_yaml_array_entry?(entry, value_key)
        return false unless entry.is_a?(Hash)

        string_keys = ['name', value_key.to_s]
        symbol_keys = [:name, value_key]

        same_keys?(entry.keys, string_keys) || same_keys?(entry.keys, symbol_keys)
      end
      private_class_method :valid_yaml_array_entry?

      def same_keys?(actual_keys, expected_keys)
        (actual_keys - expected_keys).empty? && (expected_keys - actual_keys).empty?
      end
      private_class_method :same_keys?

      def parse_dotenv_file(path, file_label:, value_key:, value_transform: method(:stringify_value))
        File.read(path).each_line.each_with_object([]) do |line, entries|
          line = line.strip
          next if line.blank? || line.start_with?('#')

          name, value = line.split('=', 2)
          name = name.strip
          raise Exceptions::ValidationError, "Invalid #{file_label} line. [#{path}]" if name.blank? || value.nil?

          entries << build_entry(name, strip_wrapping_quotes(strip_inline_comment(value.to_s).strip), value_key:, value_transform:)
        end
      end

      def stringify_value(value)
        value.is_a?(String) ? value : value.to_s
      end

      def build_entry(name, value, value_key:, value_transform:)
        raise Exceptions::ValidationError, 'Entry name must be present.' if name.nil?

        normalized_name = name.to_s
        raise Exceptions::ValidationError, 'Entry name must be present.' if normalized_name.strip.empty?

        {
          name: normalized_name,
          value_key => value_transform.call(value)
        }
      end
      private_class_method :build_entry

      def invalid_entry_message(entry_label, entry, container_identifier)
        sanitized_entry = sanitize_entry_for_message(entry)

        if container_identifier.present?
          "Invalid #{entry_label} entry for container override '#{container_identifier}'. [#{sanitized_entry}]"
        else
          "Invalid #{entry_label} entry. [#{sanitized_entry}]"
        end
      end
      private_class_method :invalid_entry_message

      def sanitize_entry_for_message(entry)
        return "Hash(size: #{entry.size}, keys: #{entry.keys.inspect})" if entry.is_a?(Hash)
        return "Array(size: #{entry.size})" if entry.is_a?(Array)
        return "String(size: #{entry.size})" if entry.is_a?(String)

        entry.inspect
      end
      private_class_method :sanitize_entry_for_message

      def strip_inline_comment(value)
        in_single_quote = false
        in_double_quote = false

        value.each_char.with_index do |char, i|
          case char
          when "'"
            in_single_quote = !in_single_quote unless in_double_quote
          when '"'
            in_double_quote = !in_double_quote unless in_single_quote
          when '#'
            return value[0, i] if inline_comment_start?(value, i, in_single_quote, in_double_quote)
          end
        end

        value
      end
      private_class_method :strip_inline_comment

      def inline_comment_start?(value, index, in_single_quote, in_double_quote)
        return false if in_single_quote || in_double_quote

        index.zero? || value[index - 1].match?(/\s/)
      end
      private_class_method :inline_comment_start?

      def strip_wrapping_quotes(value)
        return value unless value.length >= 2
        return value[1..-2] if value.start_with?('"') && value.end_with?('"')
        return value[1..-2] if value.start_with?("'") && value.end_with?("'")

        value
      end
      private_class_method :strip_wrapping_quotes

      def validate_within_base_dir!(resolved_path, base_dir, file_label, container_identifier)
        base_real = File.realpath(base_dir)
        path_real = begin
          File.realpath(resolved_path)
        rescue Errno::ENOENT
          resolved_path
        end

        return if path_real == base_real || path_real.start_with?(base_real + File::SEPARATOR)

        raise Exceptions::ValidationError,
              "#{file_label.capitalize} file path for container override '#{container_identifier}' is outside the base directory. [#{resolved_path}]"
      end
      private_class_method :validate_within_base_dir!
    end
  end
end
