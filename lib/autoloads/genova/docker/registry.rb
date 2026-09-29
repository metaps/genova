require 'shellwords'

module Genova
  module Docker
    class Registry
      def initialize(logger)
        @logger = logger
      end

      def login_and_pull
        registry_config = Settings.dig(:docker, :registry)
        return if registry_config.blank?

        url = ENV['DOCKER_REGISTRY_URL'] || config_value(registry_config, :url)
        username = ENV['DOCKER_REGISTRY_USER'] || config_value(registry_config, :username) || secret_value(registry_config, :username_secret)
        password = ENV['DOCKER_REGISTRY_PASSWORD'] || config_value(registry_config, :password) || secret_value(registry_config, :password_secret)

        return if url.blank? || username.blank? || password.blank?

        login_command = %(echo #{Shellwords.escape(password)} | docker login #{url} -u #{Shellwords.escape(username)} --password-stdin)
        filtered_command = %(echo {FILTERED} | docker login #{url} -u {FILTERED} --password-stdin)
        exit_code = Genova::Command::Executor.call(login_command, @logger, filtered_command:)

        raise Exceptions::ValidationError, "Docker registry login failed. [#{url}]" unless exit_code.zero?

        Array(config_value(registry_config, :pull_images)).each do |image|
          exit_code = Genova::Command::Executor.call("docker pull #{image}", @logger)
          raise Exceptions::ValidationError, "Docker image pull failed. [#{image}]" unless exit_code.zero?
        end
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
