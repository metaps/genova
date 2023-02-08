module Genova
  module Config
    class SettingsHelper
      class << self
        def find_repository(name_or_alias)
          values = Settings.github.repositories || []
          result = values.find do |value|
            value[:name] == name_or_alias && !value.include?(:alias) || value[:alias] == name_or_alias
          end

          result.present? ? result.to_h : nil
        end
      end
    end
  end
end
