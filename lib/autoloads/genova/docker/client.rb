module Genova
  module Docker
    class Client
      BUILD_KEY = 'com.metaps.genova.build_key'.freeze

      def initialize(code_manager, logger)
        @code_manager = code_manager
        @logger = logger
        @cipher = Genova::Utils::Cipher.new(logger)
      end

      def build_image(container_config, image_name)
        @logger.info('Building image...')
        build = parse_docker_build(container_config[:build], @cipher)

        config_base_path = Pathname(@code_manager.base_path).join('config').to_s
        docker_base_path = File.expand_path(build[:context], config_base_path)
        docker_file_path = Pathname(docker_base_path).join(build[:docker_filename]).to_s

        raise Exceptions::ValidationError, "#{build[:docker_filename]} does not exist. [#{docker_file_path}]" unless File.file?(docker_file_path)

        @logger.info("Detect Docker build path [#{docker_base_path}]")

        repository_name = image_name.match(%r{/([^:]+)})[1]
        build_value = SecureRandom.alphanumeric(8)

        build_options = {
          '-t': "#{repository_name}:latest",
          '-f': docker_file_path,
          '--label': "#{BUILD_KEY}=#{build_value}"
        }
        build_options['-m'] = Settings.docker.build.memory if Settings.dig('docker', 'build', 'memory').present?
        base_command = "docker build #{build_options.map { |key, value| "#{key} #{value}" }.join(' ')}"

        command = "#{base_command}#{build[:build_args_string]} ."
        filtered_command = "#{base_command}#{build[:build_args_filtered_string]} ."

        Genova::Command::Executor.call(command, @logger, work_dir: docker_base_path, filtered_command:)

        result = ::Docker::Image.all(all: true, filters: { label: ["#{BUILD_KEY}=#{build_value}"] }.to_json)
        raise Exceptions::ImageBuildError, "Image #{repository_name} build failed. Please check build log for details." if result.empty?

        repository_name
      end

      private

      def parse_docker_build(build, cipher)
        result = {
          build_args_string: '',
          build_args_filtered_string: ''
        }

        if build.is_a?(String)
          result[:context] = build || '.'
          result[:docker_filename] = 'Dockerfile'
        else
          result[:context] = build[:context] || '.'
          result[:docker_filename] = build[:dockerfile] || 'Dockerfile'

          if build[:args].is_a?(Hash)
            build[:args].each do |key, value|
              if cipher.encrypt_format?(value)
                result[:build_args_string] += " --build-arg #{key}='#{cipher.decrypt(value)}'"
                result[:build_args_filtered_string] += " --build-arg #{key}='{FILTERD}'"
              else
                arg = " --build-arg #{key}='#{value}'"

                result[:build_args_string] += arg
                result[:build_args_filtered_string] += arg
              end
            end
          end
        end

        result
      end
    end
  end
end
