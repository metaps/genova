module Genova
  module Docker
    class Client
      BUILD_KEY = 'com.metaps.genova.build_key'.freeze

      attr_accessor :no_cache

      def initialize(code_manager, logger)
        @code_manager = code_manager
        @logger = logger
        @cipher = Genova::Utils::Cipher.new(logger)
      end

      def build_image(container_config, repository_name)
        @logger.info('Building image...')
        build = parse_docker_build(container_config[:build])

        config_base_path = Pathname(@code_manager.base_path).join('config').to_s
        docker_base_path = File.expand_path(build[:context], config_base_path)
        docker_file_path = Pathname(docker_base_path).join(build[:docker_filename]).to_s

        raise Exceptions::ValidationError, "#{build[:docker_filename]} does not exist. [#{docker_file_path}]" unless File.file?(docker_file_path)

        @logger.info("Detect docker build path [#{docker_base_path}]")

        base_command = build_base_command(repository_name, docker_file_path)

        command = "#{base_command}#{build[:build_args_string]} ."
        filtered_command = "#{base_command}#{build[:build_args_filtered_string]} ."

        start_time = Time.now
        exit_code = Genova::Command::Executor.call(command, @logger, work_dir: docker_base_path, filtered_command:)

        raise Exceptions::ImageBuildError, "Image #{repository_name} build failed. Please check build log for details." unless exit_code.zero?

        end_time = Time.now
        build_time = (end_time - start_time).round(2)

        @logger.info("Docker build time: #{build_time} seconds.")

        build_time
      end

      private

      def build_base_command(repository_name, docker_file_path)
        options = {
          '-t': "#{repository_name}:latest",
          '-f': docker_file_path,
          '--label': "#{BUILD_KEY}=#{SecureRandom.alphanumeric(8)}"
        }
        options['-m'] = Settings.docker.build.memory if Settings.dig('docker', 'build', 'memory').present?
        options['--no-cache'] = nil if @no_cache

        "docker build #{options.map { |key, value| "#{key}#{value.present? ? " #{value}" : ''}" }.join(' ')}"
      end

      def parse_build_string(context)
        {
          build_args_string: '',
          build_args_filtered_string: '',
          context: context || '.',
          docker_filename: 'Dockerfile'
        }
      end

      def parse_build_hash(build)
        result = {
          build_args_string: '',
          build_args_filtered_string: '',
          context: build[:context] || '.',
          docker_filename: build[:dockerfile] || 'Dockerfile'
        }

        if build[:target].present?
          target_option = " --target #{build[:target]}"

          result[:build_args_string] += target_option
          result[:build_args_filtered_string] += target_option
        end

        if build[:args].is_a?(Hash)
          build[:args].each do |key, value|
            if @cipher.encrypt_format?(value)
              result[:build_args_string] += " --build-arg #{key}='#{@cipher.decrypt(value)}'"
              result[:build_args_filtered_string] += " --build-arg #{key}='{FILTERD}'"
            else
              arg = " --build-arg #{key}='#{value}'"

              result[:build_args_string] += arg
              result[:build_args_filtered_string] += arg
            end
          end
        end

        result
      end

      def parse_docker_build(build)
        if build.is_a?(String)
          parse_build_string(build)
        else
          parse_build_hash(build)
        end
      end
    end
  end
end
