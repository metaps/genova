module Genova
  module Docker
    class Client
      def initialize(repository_manager, options = {})
        @repository_manager = repository_manager
        @logger = options[:logger] || ::Logger.new(nil)
        @cipher = EcsDeployer::Util::Cipher.new
      end

      def build_image(container_config, task_definition_path)
        container = container_config[:name]
        build = parse_docker_build(container_config[:build], @cipher)

        config_base_path = Pathname(@repository_manager.base_path).join('config').to_s
        docker_base_path = File.expand_path(build[:context], config_base_path)
        docker_file_path = Pathname(docker_base_path).join(build[:docker_filename]).to_s

        raise Genova::Config::ValidationError, "#{build[:docker_filename]} does not exist. [#{docker_file_path}]" unless File.exist?(docker_file_path)

        task_definition_config = @repository_manager.load_task_definition_config('config/' + task_definition_path)
        container_definition = task_definition_config[:container_definitions].find { |i| i[:name] == container.to_s }

        raise Genova::Config::ValidationError, "'#{container}' container does not exist in task definition." if container_definition.nil?

        repository_name = container_definition[:image].match(%r{/([^:]+)})[1]

        command = "docker build -t #{repository_name}:latest -f #{docker_file_path} .#{build[:build_args]}"
        @logger.info("Docker build path: #{docker_base_path}")

        executor = Genova::Command::Executor.new(work_dir: docker_base_path, logger: @logger)
        executor.command(command)

        repository_name
      end

      private

      def parse_docker_build(build, cipher)
        result = {
          build_args: ''
        }

        if build.is_a?(String)
          result[:context] = build || '.'
          result[:docker_filename] = 'Dockerfile'
        else
          result[:context] = build[:context] || '.'
          result[:docker_filename] = build[:dockerfile] || 'Dockerfile'

          if build[:args].is_a?(Hash)
            build[:args].each do |key, value|
              value = cipher.decrypt(value) if cipher.encrypt_value?(value)
              result[:build_args] += " --build-arg #{key}='#{value}'"
            end
          end
        end

        result
      end
    end
  end
end
