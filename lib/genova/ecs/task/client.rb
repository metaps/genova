module Genova
  module Ecs
    module Task
      class Client
        def initialize
          @ecs_client = Aws::ECS::Client.new
          @cipher = Genova::Utils::Cipher.new
        end

        def register(path, params = {})
          raise IOError, "File does not exist. [#{path}]" unless File.exist?(path)

          yaml = YAML.load(File.read(path))
          task_definition = Oj.load(Oj.dump(yaml), symbol_keys: true)

          replace_parameter_variables!(task_definition, params)
          decrypt_environment_variables!(task_definition)

          task_definition[:tags] = [] if task_definition[:tags].nil?
          task_definition[:tags] << { key: 'genova.version', value: Version::STRING }
          task_definition[:tags] << { key: 'genova.build', value: params[:tag] }

          result = @ecs_client.register_task_definition(task_definition)
          result[:task_definition]
        end

        private

        def replace_parameter_variables!(variables, params = {})
          variables.each do |variable|
            if variable.class == Array || variable.class == Hash
              replace_parameter_variables!(variable, params)
            elsif variable.class == String
              params.each do |replace_key, replace_value|
                variable.gsub!("{{#{replace_key}}}", replace_value)
              end
            end
          end
        end

        def decrypt_environment_variables!(task_definition)
          raise Exceptions::TaskDefinitionValidationError, '\'container_definitions\' is undefined.' unless task_definition.key?(:container_definitions)

          task_definition[:container_definitions].each do |container_definition|
            next unless container_definition.key?(:environment)

            container_definition[:environment].each do |environment|
              if environment[:value].class == String
                environment[:value] = @cipher.decrypt(environment[:value]) if @cipher.encrypt_format?(environment[:value])
              else
                # https://github.com/naomichi-y/ecs_deployer/issues/6
                environment[:value] = environment[:value].to_s
              end
            end
          end
        end
      end
    end
  end
end
