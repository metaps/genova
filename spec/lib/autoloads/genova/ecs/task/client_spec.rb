require 'rails_helper'

module Genova
  module Ecs
    module Task
      describe Client do
        let(:cipher) { double(Utils::Cipher) }
        let(:task_client) { Ecs::Task::Client.new(::Logger.new($stdout)) }
        let(:ecs_client) { double(Aws::ECS::Client) }
        let(:register_task_definition_response) { double(Aws::ECS::Types::RegisterTaskDefinitionResponse) }
        let(:task_definition) { double(Aws::ECS::Types::TaskDefinition) }

        before do
          allow(Utils::Cipher).to receive(:new).and_return(cipher)
          allow(Aws::ECS::Client).to receive(:new).and_return(ecs_client)
          allow(Aws::KMS::Client).to receive(:new)
        end

        describe 'register' do
          it 'should return new task' do
            allow(File).to receive(:file?).and_return(true)
            allow(File).to receive(:read).and_return(
              {
                container_definitions: []
              }.to_yaml
            )

            allow(task_definition).to receive(:[]).with(:task_definition_arn)
            allow(register_task_definition_response).to receive(:[]).with(:task_definition).and_return(task_definition)
            allow(ecs_client).to receive(:register_task_definition).and_return(register_task_definition_response)

            expect(task_client.register(any_args)).to be_a(task_definition.class)
          end

          it 'should load environment from external files' do
            task_definition_path = '/repo/config/deploy/web.yml'
            env_file_path = '/repo/config/deploy/app.env'
            yaml_file_path = '/repo/config/deploy/shared.yml'

            allow(File).to receive(:file?).with(task_definition_path).and_return(true)
            allow(File).to receive(:file?).with(env_file_path).and_return(true)
            allow(File).to receive(:file?).with(yaml_file_path).and_return(true)
            allow(File).to receive(:read).with(task_definition_path).and_return(
              {
                container_definitions: [
                  {
                    name: 'app',
                    environment_from_files: [
                      './app.env',
                      './shared.yml'
                    ],
                    environment: [
                      {
                        name: 'INLINE_ONLY',
                        value: 'inline'
                      },
                      {
                        name: 'SHARED_KEY',
                        value: 'inline_override'
                      }
                    ]
                  }
                ]
              }.to_yaml
            )
            allow(File).to receive(:read).with(env_file_path).and_return("DOTENV_KEY=dotenv\nFILE_OVERRIDE=dotenv\nSHARED_KEY=dotenv\n")
            allow(File).to receive(:read).with(yaml_file_path).and_return(
              {
                'YAML_KEY' => 1,
                'FILE_OVERRIDE' => 'yaml',
                'SHARED_KEY' => 'yaml'
              }.to_yaml
            )

            allow(cipher).to receive(:encrypt_format?).and_return(false)
            allow(task_definition).to receive(:[]).with(:task_definition_arn)
            allow(register_task_definition_response).to receive(:[]).with(:task_definition).and_return(task_definition)
            expect(ecs_client).to receive(:register_task_definition) do |params|
              container_definition = params[:container_definitions].find { |definition| definition[:name] == 'app' }

              expect(container_definition).to include(name: 'app')
              expect(
                container_definition[:environment].to_h { |environment| [environment[:name], environment[:value]] }
              ).to eq(
                'DOTENV_KEY' => 'dotenv',
                'FILE_OVERRIDE' => 'yaml',
                'YAML_KEY' => '1',
                'INLINE_ONLY' => 'inline',
                'SHARED_KEY' => 'inline_override'
              )

              register_task_definition_response
            end

            expect(task_client.register(task_definition_path)).to be_a(task_definition.class)
          end
        end

        describe 'merge_task_parameters!' do
          let(:task_definition) do
            {
              container_definitions: [
                {
                  name: 'app',
                  memory: 256,
                  command: [
                    'ls'
                  ],
                  environment: [
                    {
                      name: 'KEY1',
                      value: 'value1'
                    },
                    {
                      name: 'KEY2',
                      value: 'value2'
                    }
                  ]
                }
              ]
            }
          end
          let(:task_overrides) do
            {
              container_definitions: [
                {
                  name: 'app',
                  memory: 512,
                  command: [
                    'date'
                  ],
                  essential: true,
                  environment: [
                    {
                      name: 'KEY2',
                      value: 'value2_override'
                    },
                    {
                      name: 'KEY3',
                      value: 'value3'
                    }
                  ]
                }
              ]
            }
          end

          it 'should return merge parameters' do
            expect(task_client.send(:merge_task_parameters!, task_definition, task_overrides)).to eq(
              {
                container_definitions: [
                  {
                    name: 'app',
                    memory: 512,
                    command: [
                      'date'
                    ],
                    essential: true,
                    environment: [
                      {
                        name: 'KEY1',
                        value: 'value1'
                      },
                      {
                        name: 'KEY2',
                        value: 'value2_override'
                      },
                      {
                        name: 'KEY3',
                        value: 'value3'
                      }
                    ]
                  }
                ]
              }
            )
          end
        end

        describe 'decrypt_environment_variables' do
          let(:variables) do
            {
              container_definitions: [{
                environment: [{
                  name: 'NAME',
                  value: 'VALUE'
                }, {
                  name: 'NAME',
                  value: 1
                }, {
                  name: 'NAME',
                  value: '${ENCRYPT_VALUE}'
                }]
              }]
            }
          end

          before do
            allow(cipher).to receive(:encrypt_format?).with('VALUE').and_return(false)
            allow(cipher).to receive(:encrypt_format?).with(1).and_return(false)
            allow(cipher).to receive(:encrypt_format?).with('${ENCRYPT_VALUE}').and_return('decrypted_value')
            allow(cipher).to receive(:decrypt).and_return('decrypted_value')
          end

          it 'should return string value' do
            task_client.send(:decrypt_environment_variables!, variables)
            expect(variables[:container_definitions][0][:environment][0][:value]).to eq('VALUE')
          end

          it 'should return numeric value' do
            task_client.send(:decrypt_environment_variables!, variables)
            expect(variables[:container_definitions][0][:environment][1][:value]).to eq('1')
          end

          it 'should return decrypted value' do
            task_client.send(:decrypt_environment_variables!, variables)
            expect(variables[:container_definitions][0][:environment][2][:value]).to eq('decrypted_value')
          end
        end

        describe 'load_environment_from_files!' do
          let(:task_definition_path) { '/repo/config/deploy/web.yml' }

          it 'should raise error when container_definitions is nil' do
            variables = {
              container_definitions: nil
            }

            expect do
              task_client.send(:load_environment_from_files!, variables, task_definition_path)
            end.to raise_error(Exceptions::TaskDefinitionValidationError, "'container_definitions' must be an array.")
          end

          it 'should raise error when container_definitions is not an array' do
            variables = {
              container_definitions: {}
            }

            expect do
              task_client.send(:load_environment_from_files!, variables, task_definition_path)
            end.to raise_error(Exceptions::TaskDefinitionValidationError, "'container_definitions' must be an array.")
          end

          it 'should raise error when container_definition is not a hash' do
            variables = {
              container_definitions: ['invalid']
            }

            expect do
              task_client.send(:load_environment_from_files!, variables, task_definition_path)
            end.to raise_error(Exceptions::TaskDefinitionValidationError, "Each entry in 'container_definitions' must be a hash.")
          end

          it 'should raise error when environment file does not exist' do
            variables = {
              container_definitions: [
                {
                  environment_from_files: ['./missing.env']
                }
              ]
            }

            allow(File).to receive(:file?).with('/repo/config/deploy/missing.env').and_return(false)

            expect do
              task_client.send(:load_environment_from_files!, variables, task_definition_path)
            end.to raise_error(Exceptions::TaskDefinitionValidationError, 'Environment file does not exist. [/repo/config/deploy/missing.env]')
          end

          it 'should raise error when environment file path is nil' do
            variables = {
              container_definitions: [
                {
                  name: 'app',
                  environment_from_files: [nil]
                }
              ]
            }

            expect do
              task_client.send(:load_environment_from_files!, variables, task_definition_path)
            end.to raise_error(Exceptions::TaskDefinitionValidationError, "Invalid environment file path for container 'app'. [nil]")
          end

          it 'should raise error when environment file path is empty' do
            variables = {
              container_definitions: [
                {
                  name: 'app',
                  environment_from_files: ['']
                }
              ]
            }

            expect do
              task_client.send(:load_environment_from_files!, variables, task_definition_path)
            end.to raise_error(Exceptions::TaskDefinitionValidationError, "Invalid environment file path for container 'app'. [\"\"]")
          end
        end
      end
    end
  end
end
