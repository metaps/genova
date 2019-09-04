require 'rails_helper'

module Genova
  module Ecs
    module Task
      describe Client do
        let(:cipher_mock) { double(Utils::Cipher) }
        let(:task_client) { Ecs::Task::Client.new }
        let(:ecs_client_mock) { double(Aws::ECS::Client) }
        let(:task_definition_mock) { double(Aws::ECS::Types::TaskDefinition) }

        before do
          allow(Utils::Cipher).to receive(:new).and_return(cipher_mock)
          allow(Aws::ECS::Client).to receive(:new).and_return(ecs_client_mock)
          allow(Aws::KMS::Client).to receive(:new)
        end

        describe 'register' do
          it 'should be return new task' do
            allow(File).to receive(:exist?).and_return(true)
            allow(File).to receive(:read).and_return('')
            allow(task_client).to receive(:register_hash).and_return(task_definition_mock)

            expect(task_client.register(any_args)).to be_a(task_definition_mock.class)
          end
        end

        describe 'register_hash' do
          it 'should be registered task definition' do
            allow(task_client).to receive(:replace_parameter_variables!)
            allow(task_client).to receive(:decrypt_environment_variables!)
            allow(ecs_client_mock).to receive(:register_task_definition).and_return(task_definition: task_definition_mock)

            expect(task_client.register_hash({})).to be_a(task_definition_mock.class)
          end
        end

        describe 'register_clone' do
          before do
            allow(ecs_client_mock).to receive(:describe_services).and_return(
              services: [
                service_name: 'service'
              ]
            )
            allow(ecs_client_mock).to receive(:describe_task_definition).and_return(
              task_definition: {}
            )
            allow(task_client).to receive(:register_hash).and_return(task_definition_mock)
          end

          context 'when find task definition' do
            it 'should be return new task definition arn' do
              expect(task_client.register_clone('cluster', 'service')).to eq(task_definition_mock)
            end
          end

          context 'when not found task definition' do
            it 'should be return new task definition arn' do
              expect { task_client.register_clone('cluster', 'undefined') }.to raise_error(Exceptions::ServiceNotFoundError)
            end
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
            allow(cipher_mock).to receive(:encrypt_value?).with('VALUE').and_return(false)
            allow(cipher_mock).to receive(:encrypt_value?).with(1).and_return(false)
            allow(cipher_mock).to receive(:encrypt_value?).with('${ENCRYPT_VALUE}').and_return('decrypted_value')
            allow(cipher_mock).to receive(:decrypt).and_return('decrypted_value')
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
