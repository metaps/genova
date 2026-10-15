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

        # `alias` identifies which `deploy.yml` a step deploys when a repository has multiple
        # `base_path`. An alias that resolves to nothing, or to an entry of another repository,
        # would otherwise deploy a different target without any error.
        def find_step_repository(step)
          repository_settings = find_repository(step[:alias].presence || step[:repository])
          return repository_settings if step[:alias].blank?

          raise Exceptions::ValidationError, "Alias is undefined. [#{step[:alias]}]" if repository_settings.nil?
          raise Exceptions::ValidationError, "Alias belongs to #{repository_settings[:name]}. [#{step[:alias]}]" if step[:repository].present? && repository_settings[:name] != step[:repository]

          repository_settings
        end
      end
    end
  end
end
