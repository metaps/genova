module CI
  module Deploy
    module Config
      class TaskDefinitionConfig
        attr_reader :path

        def initialize(repos_path, service)
          @path = Pathname(repos_path).join('config', 'deploy', "#{service}.yml").to_s

          unless File.exist?(@path)
            raise "Service definition is undefined. [#{@path}]"
          end
        end

        def read
          YAML.load(File.read(@path)).deep_symbolize_keys
        end
      end
    end
  end
end
