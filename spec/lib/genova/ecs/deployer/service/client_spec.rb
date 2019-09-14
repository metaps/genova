require 'rails_helper'

module Genova
  module Ecs
    module Deployer
      module Service
        describe Client do
          let(:logger) { ::Logger.new(nil) }
          let(:ecs_client_mock) { double(Aws::ECS::Client) }
          let(:service_client) { Ecs::Deployer::Service::Client.new('cluster', logger) }

          before do
            allow(Aws::ECS::Client).to receive(:new).and_return(ecs_client_mock)
            allow(Ecs::Task::Client).to receive(:new)
          end

          describe 'update' do
            it 'should be return service arn' do
              update_service_response_mock = double(Aws::ECS::Types::UpdateServiceResponse)
              service_mock = double(Aws::ECS::Types::Service)

              allow(service_mock).to receive(:task_definition)
              allow(update_service_response_mock).to receive(:service).and_return(service_mock)
              allow(ecs_client_mock).to receive(:update_service).and_return(update_service_response_mock)
              allow(service_client).to receive(:wait_for_deploy)

              expect(service_client.update('service')).to be_a(service_mock.class)
            end
          end

          describe 'exist?' do
            before do
              describe_services_response_mock = double(Aws::ECS::Types::DescribeServicesResponse)
              allow(describe_services_response_mock).to receive(:[]).with(:services).and_return(
                [
                  {
                    service_name: 'service_name',
                    status: 'ACTIVE'
                  }
                ]
              )
              allow(ecs_client_mock).to receive(:describe_services).and_return(describe_services_response_mock)
            end

            context 'when exist service' do
              it 'should be return Aws::ECS::Types::Service' do
                expect(service_client.send(:exist?, 'service_name')).to be(true)
              end
            end

            context 'when not exist service' do
              it 'should be return false' do
                expect(service_client.send(:exist?, 'undefined')).to eq(false)
              end
            end
          end

          describe 'deploy_status' do
            before do
              allow(service_client).to receive(:detect_stopped_task)
              allow(ecs_client_mock).to receive(:list_tasks).and_return(task_arns: ['running_task_arn'])
            end

            let(:describe_tasks_response_mock) { double(Aws::ECS::Types::DescribeTasksResponse) }
            let(:task_mock) { double(Aws::ECS::Types::Task) }

            context 'when deploying' do
              it 'should be return result' do
                allow(task_mock).to receive(:[]).with(:task_definition_arn).and_return('old_task_arn')
                allow(task_mock).to receive(:[]).with(:last_status).and_return('RUNNING')
                allow(describe_tasks_response_mock).to receive(:[]).with(:tasks).and_return([task_mock])
                allow(ecs_client_mock).to receive(:describe_tasks).and_return(describe_tasks_response_mock)

                result = service_client.send(:deploy_status, 'service', 'new_task_arn')
                expect(result[:current_task_count]).to eq(1)
                expect(result[:new_registerd_task_count]).to eq(0)
              end
            end

            context 'when deployed' do
              it 'should be return result' do
                allow(task_mock).to receive(:[]).with(:task_definition_arn).and_return('new_task_arn')
                allow(task_mock).to receive(:[]).with(:last_status).and_return('RUNNING')
                allow(describe_tasks_response_mock).to receive(:[]).with(:tasks).and_return([task_mock, task_mock])
                allow(ecs_client_mock).to receive(:describe_tasks).and_return(describe_tasks_response_mock)

                result = service_client.send(:deploy_status, 'service', 'new_task_arn')
                expect(result[:current_task_count]).to eq(0)
                expect(result[:new_registerd_task_count]).to eq(2)
              end
            end
          end

          describe 'wait_for_deploy' do
            before do
              allow(service_client).to receive(:exist?).and_return(true)

              service_client.wait_timeout = 0.3
              service_client.polling_interval = 0.1
            end

            context 'when deploy complete' do
              it 'shuld be return success' do
                allow(service_client).to receive(:deploy_status).and_return(new_registerd_task_count: 1,
                                                                            current_task_count: 0,
                                                                            status_logs: ['task_status_logs'])
                allow(ecs_client_mock).to receive(:describe_services).and_return(services: [desired_count: 1])
                expect { service_client.send(:wait_for_deploy, 'service', 'task_definition_arn') }.to_not raise_error
              end
            end

            context 'when timed out' do
              it 'shuld be return error' do
                allow(service_client).to receive(:deploy_status).and_return(new_registerd_task_count: 0,
                                                                            current_task_count: 1,
                                                                            status_logs: ['task_status_logs'])
                allow(ecs_client_mock).to receive(:describe_services).and_return(services: [desired_count: 1])
                expect { service_client.send(:wait_for_deploy, 'service', 'task_definition_arn') }.to raise_error(Exceptions::DeployTimeoutError)
              end
            end
          end
        end
      end
    end
  end
end
