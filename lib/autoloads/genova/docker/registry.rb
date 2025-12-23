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

        url = ENV['DOCKER_REGISTRY_URL'] || registry_config[:url] || registry_config.try(:url)
        username = ENV['DOCKER_REGISTRY_USER'] || registry_config[:username]
        password = ENV['DOCKER_REGISTRY_PASSWORD'] || registry_config[:password]

        return if url.blank? || username.blank? || password.blank?

        login_command = %(echo #{Shellwords.escape(password)} | docker login #{url} -u #{Shellwords.escape(username)} --password-stdin)
        filtered_command = %(echo {FILTERED} | docker login #{url} -u {FILTERED} --password-stdin)
        Genova::Command::Executor.call(login_command, @logger, filtered_command:)

        Array(registry_config[:pull_images]).each do |image|
          Genova::Command::Executor.call("docker pull #{image}", @logger)
        end
      end
    end
  end
end
