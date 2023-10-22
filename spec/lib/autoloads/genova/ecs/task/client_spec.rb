require 'rails_helper'

module Genova
  module Ecs
    module Task
      describe Client do
        let(:cipher) { double(Utils::Cipher) }
        let(:task_client) { Ecs::Task::Client.new(::Logger.new($stdout)) }
        let(:ecs_client) { double(Aws::ECS::Client) }
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

            allow(task_definition).to receive(:[]).with(:task_definition).and_return(double(Aws::ECS::Types::TaskDefinition))
            allow(ecs_client).to receive(:register_task_definition).and_return(task_definition)

            expect(task_client.register(any_args)).to be_a(task_definition.class)
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

          it 'shuold be return string value' do
            task_client.send(:decrypt_environment_variables!, variables)
            expect(variables[:container_definitions][0][:environment][0][:value]).to eq('VALUE')
          end

          it 'shuold be return numeric value' do
            task_client.send(:decrypt_environment_variables!, variables)
            expect(variables[:container_definitions][0][:environment][1][:value]).to eq('1')
          end

          it 'shuold be return decrypted value' do
            task_client.send(:decrypt_environment_variables!, variables)
            expect(variables[:container_definitions][0][:environment][2][:value]).to eq('decrypted_value')
          end
        end
      end
    end
  end
end
