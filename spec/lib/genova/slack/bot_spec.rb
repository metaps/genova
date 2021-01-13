require 'rails_helper'

module Genova
  module Slack
    describe Bot do
      let(:bot) { Genova::Slack::Bot.new }
      let(:slack_web_client_mock) { double(::Slack::Web::Client) }

      before do
        Redis.current.flushdb

        allow(::Slack::Web::Client).to receive(:new).and_return(slack_web_client_mock)
        allow(slack_web_client_mock).to receive(:chat_postMessage)
      end

      describe 'post_choose_history' do
        it 'should be not error' do
          expect { bot.post_choose_history({}) }.to raise_error(Genova::Exceptions::NotFoundError)
        end
      end

      describe 'post_choose_repository' do
        it 'should be not error' do
          expect { bot.post_choose_repository }.not_to raise_error(Genova::Exceptions::NotFoundError)
        end
      end

      describe 'post_choose_cluster' do
        include_context 'load code_manager_mock'

        it 'should be not error' do
          expect { bot.post_choose_cluster({}) }.not_to raise_error(Genova::Exceptions::NotFoundError)
        end
      end

      describe 'post_choose_target' do
        it 'should be not error' do
          allow(Genova::Slack::BlockKitElementObject).to receive(:target_options).and_return(
            [
              options: [
                {
                  text: 'text',
                  value: 'value'
                }
              ]
            ]
          )
          expect { bot.post_choose_target({}) }.not_to raise_error
        end
      end

      describe 'post_confirm_deploy' do
        let(:params) do
          {
            confirm: true,
            service: 'service'
          }
        end

        let(:github_client_mock) { double(Genova::Github::Client) }
        include_context 'load code_manager_mock'

        let(:ecs_client_mock) { double(Aws::ECS::Client) }
        let(:describe_services_response_mock) { double(Aws::ECS::Types::DescribeServicesResponse) }
        let(:describe_task_definition_response_mock) { double(Aws::ECS::Types::DescribeTaskDefinitionResponse) }
        let(:service_mock) { double(Aws::ECS::Types::Service) }
        let(:task_definition_mock) { double(Aws::ECS::Types::TaskDefinition) }
        let(:container_definitions) { double(Array) }

        it 'should be not error' do
          allow(service_mock).to receive(:task_definition)
          allow(describe_services_response_mock).to receive(:services).and_return([service_mock])
          allow(container_definitions).to receive(:each).and_yield(image: 'build-xxx')
          allow(task_definition_mock).to receive(:container_definitions).and_return(container_definitions)
          allow(describe_task_definition_response_mock).to receive(:task_definition).and_return(task_definition_mock)
          allow(ecs_client_mock).to receive(:describe_services).and_return(describe_services_response_mock)
          allow(ecs_client_mock).to receive(:describe_task_definition).and_return(describe_task_definition_response_mock)

          allow(Aws::ECS::Client).to receive(:new).and_return(ecs_client_mock)

          expect { bot.post_confirm_deploy(params) }.not_to raise_error
        end
      end

      describe 'post_detect_auto_deploy' do
        let(:deploy_job) { DeployJob.new }

        it 'should be call bot' do
          expect { bot.post_detect_auto_deploy(deploy_job) }.to_not raise_error
        end
      end
    end
  end
end
