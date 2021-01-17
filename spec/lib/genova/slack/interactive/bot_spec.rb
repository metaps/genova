require 'rails_helper'

module Genova
  module Slack
    module Interactive
      describe Bot do
        let(:bot) { Genova::Slack::Interactive::Bot.new }
        let(:slack_web_client_mock) { double(::Slack::Web::Client) }

        before do
          Redis.current.flushdb

          allow(::Slack::Web::Client).to receive(:new).and_return(slack_web_client_mock)
          allow(slack_web_client_mock).to receive(:chat_postMessage)
        end

        describe 'ask_history' do
          it 'should be not error' do
            expect { bot.ask_history({}) }.to raise_error(Genova::Exceptions::NotFoundError)
          end
        end

        describe 'ask_repository' do
          it 'should be not error' do
            expect { bot.ask_repository }.not_to raise_error(Genova::Exceptions::NotFoundError)
          end
        end

        describe 'ask_cluster' do
          include_context 'load code_manager_mock'

          it 'should be not error' do
            expect { bot.ask_cluster({}) }.not_to raise_error(Genova::Exceptions::NotFoundError)
          end
        end

        describe 'ask_target' do
          it 'should be not error' do
            allow(Genova::Slack::BlockKit::ElementObject).to receive(:target_options).and_return(
              [
                options: [
                  {
                    text: 'text',
                    value: 'value'
                  }
                ]
              ]
            )
            expect { bot.ask_target({}) }.not_to raise_error
          end
        end

        describe 'ask_confirm_deploy' do
          let(:params) do
            {
              service: 'service'
            }
          end
          let(:code_manager_mock) { double(Genova::CodeManager::Git) }
          let(:ecs_client_mock) { double(Aws::ECS::Client) }
          let(:describe_services_response_mock) { double(Aws::ECS::Types::DescribeServicesResponse) }
          let(:service_mock) { double(Aws::ECS::Types::Service) }
          let(:describe_task_definition_response_mock) { double(Aws::ECS::Types::DescribeTaskDefinitionResponse) }

          it 'should be not error' do
            allow(code_manager_mock).to receive(:origin_last_commit).and_return('xxx')
            allow(code_manager_mock).to receive(:find_commit).and_return('yyy')
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager_mock)
            allow(Aws::ECS::Client).to receive(:new).and_return(ecs_client_mock)
            allow(describe_services_response_mock).to receive(:services).and_return([service_mock])
            allow(ecs_client_mock).to receive(:describe_services).and_return(describe_services_response_mock)
            allow(service_mock).to receive(:task_definition)
            allow(describe_task_definition_response_mock).to receive(:[]).with(:tags).and_return([{
                                                                                                   key: 'genova.build'
                                                                                                 }])
            allow(ecs_client_mock).to receive(:describe_task_definition).and_return(describe_task_definition_response_mock)

            expect { bot.ask_confirm_deploy(params, true) }.not_to raise_error
          end
        end
      end
    end
  end
end
