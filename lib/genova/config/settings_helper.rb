module Genova
  module Config
    class SettingsHelper
      class << self
        def find_repository(name_or_alias)
          repositories = Settings.github.repositories || []
          result = repositories.find do |repository|
            repository[:name] == name_or_alias && !repository.include?(:alias) || repository[:alias] == name_or_alias
          end

          result.present? ? result.to_h : nil
        end
      end
    end
  end
end
