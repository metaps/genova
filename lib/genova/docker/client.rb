module Genova
  module Docker
    class Client
      def initialize(repository_manager, options = {})
        @repository_manager = repository_manager
        @logger = options[:logger] || ::Logger.new(STDOUT)
        @cipher = EcsDeployer::Util::Cipher.new(profile: options[:profile], region: options[:region])
      end

      def self.build_tag_revision(deploy_job_id, commit_id)
        "build-#{deploy_job_id}_#{commit_id}"
      end

      def build_images(service, service_config)
        repository_names = []

        containers_config = service_config[:containers]
        containers_config.each do |params|
          container = params[:name]
          build = parse_docker_build(params[:build], @cipher)

          config_base_path = Pathname(@repository_manager.path).join('config').to_s
          docker_base_path = File.expand_path(build[:context], config_base_path)
          docker_file_path = Pathname(docker_base_path).join(build[:docker_filename]).to_s

          raise Genova::Config::DeployConfigError, "#{build[:docker_filename]} does not exist. [#{docker_file_path}]" unless File.exist?(docker_file_path)

          task_definition_config = @repository_manager.load_task_definition_config(service)
          container_definition = task_definition_config[:container_definitions].find { |i| i[:name] == container.to_s }
          repository_name = container_definition[:image].match(%r{/([^:]+)})[1]

          command = "docker build -t #{repository_name}:latest -f #{docker_file_path} .#{build[:build_args]}"

          executor = Genova::Command::Executor.new(work_dir: docker_base_path, logger: @logger)
          executor.command(command)

          repository_names.push(repository_name)
        end

        repository_names
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
