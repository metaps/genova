module Genova
  module Config
    class SettingsHelper
      class << self
        def find_repository(name_or_alias)
          result = {}

          Settings.github.repositories.each do |repository|
            next unless (repository[:name] == name_or_alias && !repository.include?(:alias)) || repository[:alias] == name_or_alias

            result = {
              name: repository[:name],
              base_path: repository[:base_path],
            }
          end

          raise Exceptions::NotFoundError, "'#{name_or_alias}' repository is not found in config/settings.local.yml file." if result.size.zero?

          result
        end
      end
    end
  end
end
