module Genova
  module Docker
    class Client
      BUILD_KEY = 'com.metaps.genova.build_key'.freeze

      def initialize(code_manager, options = {})
        @code_manager = code_manager
        @logger = options[:logger] || ::Logger.new(STDOUT)
        @cipher = Genova::Utils::Cipher.new
      end

      def build_image(container_config, task_definition_path)
        container = container_config[:name]
        build = parse_docker_build(container_config[:build], @cipher)

        config_base_path = Pathname(@code_manager.base_path).join('config').to_s
        docker_base_path = File.expand_path(build[:context], config_base_path)
        docker_file_path = Pathname(docker_base_path).join(build[:docker_filename]).to_s

        raise Exceptions::ValidationError, "#{build[:docker_filename]} does not exist. [#{docker_file_path}]" unless File.exist?(docker_file_path)

        task_definition_config = @code_manager.load_task_definition_config('config/' + task_definition_path)
        container_definition = task_definition_config[:container_definitions].find { |i| i[:name] == container.to_s }

        raise Exceptions::ValidationError, "'#{container}' container does not exist in task definition." if container_definition.nil?

        repository_name = container_definition[:image].match(%r{/([^:]+)})[1]
        build_value = SecureRandom.alphanumeric(8)

        build_options = {
          '-t': "#{repository_name}:latest",
          '-f': docker_file_path,
          '--label': BUILD_KEY + '=' + build_value
        }
        build_options['-m'] = Settings.docker.build.memory if Settings.dig('docker', 'build', 'memory').present?
        build_option_string = build_options.map { |key, value| "#{key} #{value}" }.join(' ') + build[:build_args]

        command = "docker build #{build_option_string} ."
        @logger.info("Docker build path: #{docker_base_path}")

        executor = Genova::Command::Executor.new(work_dir: docker_base_path, logger: @logger)
        executor.command(command)

        result = ::Docker::Image.all(all: true, filters: { label: ["#{BUILD_KEY}=#{build_value}"] }.to_json)
        raise Exceptions::ImageBuildError, "Image #{repository_name} build failed. Please check build log for details." if result.empty?

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
              value = cipher.decrypt(value) if cipher.encrypt_format?(value)
              result[:build_args] += " --build-arg #{key}='#{value}'"
            end
          end
        end

        result
      end
    end
  end
end
