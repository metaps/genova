module Genova
  module Ecs
    module Task
      class Client
        def initialize
          @ecs_client = Aws::ECS::Client.new
          @cipher = Genova::Utils::Cipher.new
        end

        def register(path, replace_variables = {})
          raise IOError, "File does not exist. [#{path}]" unless File.exist?(path)

          register_hash(YAML.load(File.read(path)), replace_variables)
        end

        def register_hash(task_definition, replace_variables = {})
          task_definition = Oj.load(Oj.dump(task_definition), symbol_keys: true)

          replace_parameter_variables!(task_definition, replace_variables)
          decrypt_environment_variables!(task_definition)

          task_definition[:tags] = [] if task_definition[:tags].nil?
          task_definition[:tags] << { key: 'genova', value: VERSION::STRING }

          result = @ecs_client.register_task_definition(task_definition)
          result[:task_definition]
        end

        private

        def replace_parameter_variables!(variables, replace_variables = {})
          variables.each do |variable|
            if variable.class == Array || variable.class == Hash
              replace_parameter_variables!(variable, replace_variables)
            elsif variable.class == String
              replace_variables.each do |replace_key, replace_value|
                variable.gsub!("{{#{replace_key}}}", replace_value)
              end
            end
          end
        end

        def decrypt_environment_variables!(task_definition)
          raise Exceptions::TaskDefinitionValidateError, '\'container_definition\' is undefined.' unless task_definition.key?(:container_definitions)

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
