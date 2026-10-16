module Genova
  module Docker
    class Registry
      def initialize(logger)
        @logger = logger
      end

      def login
        registry_config = Settings.dig(:docker, :registry)
        return if registry_config.blank?

        url = ENV['DOCKER_REGISTRY_URL'].presence || config_value(registry_config, :url)
        username = ENV['DOCKER_REGISTRY_USER'].presence || config_value(registry_config, :username) || secret_value(registry_config, :username_secret)
        password = ENV['DOCKER_REGISTRY_PASSWORD'].presence || config_value(registry_config, :password) || secret_value(registry_config, :password_secret)

        return if [url, username, password, config_value(registry_config, :username_secret), config_value(registry_config, :password_secret)].all?(&:blank?)

        if url.blank? || username.blank? || password.blank?
          @logger.warn('Docker registry login skipped because URL, username or password is missing.')
          raise Exceptions::ValidationError, 'Docker registry URL, username and password are required to log in.'
        end

        login_command = ['docker', 'login', url, '-u', username, '--password-stdin']
        filtered_command = %(docker login #{url} -u {FILTERED} --password-stdin)
        exit_code = Genova::Command::Executor.call(login_command, @logger, filtered_command:, stdin_data: password)

        raise Exceptions::ValidationError, "Docker registry login failed. [#{url}]" unless exit_code.zero?
      end

      private

      def config_value(registry_config, key)
        registry_config[key] || registry_config.try(key)
      end

      def secret_value(registry_config, key)
        secret_id = config_value(registry_config, key)
        Genova::Utils::SecretFetcher.call(secret_id)
      end
    end
  end
end
