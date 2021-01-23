require 'rails_helper'

module Genova
  module Slack
    module Interactive
      describe Bot do
        let(:bot) { Genova::Slack::Interactive::Bot.new }
        let(:client_mock) { double(::Slack::Web::Client) }

        before do
          allow(::Slack::Web::Client).to receive(:new).and_return(client_mock)
          allow(client_mock).to receive(:chat_postMessage)
        end

        describe 'send_message' do
          it 'should be not error' do
            expect { bot.send_message('message') }.not_to raise_error
          end
        end

        describe 'ask_history' do
          let(:array_mock) { double(Array) }

          it 'should be not error' do
            allow(array_mock).to receive(:size).and_return(1)
            allow(BlockKit::ElementObject).to receive(:history_options).and_return(array_mock)

            expect { bot.ask_history({}) }.not_to raise_error
          end
        end

        describe 'ask_repository' do
          it 'should be not error' do
            expect { bot.ask_repository({}) }.not_to raise_error
          end
        end

        describe 'ask_branch' do
          let(:array_mock) { double(Array) }

          it 'should be not error' do
            allow(array_mock).to receive(:size).and_return(1)
            allow(BlockKit::ElementObject).to receive(:branch_options)
            allow(BlockKit::ElementObject).to receive(:tag_options).and_return(array_mock)

            expect { bot.ask_branch({}) }.not_to raise_error
          end
        end

        describe 'ask_cluster' do
          let(:array_mock) { double(Array) }

          it 'should be not error' do
            allow(array_mock).to receive(:size).and_return(1)
            allow(BlockKit::ElementObject).to receive(:cluster_options).and_return(array_mock)

            expect { bot.ask_cluster({}) }.not_to raise_error
          end
        end

        describe 'ask_target' do
          let(:array_mock) { double(Array) }

          it 'should be not error' do
            allow(array_mock).to receive(:size).and_return(1)
            allow(BlockKit::ElementObject).to receive(:target_options).and_return(array_mock)

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

            expect { bot.ask_confirm_deploy(params, show_target: true) }.not_to raise_error
          end
        end

        describe 'detect_github_event' do
          let(:deploy_job_mock) { double(DeployJob) }

          it 'should be not error' do
            allow(deploy_job_mock).to receive(:repository)
            allow(deploy_job_mock).to receive(:account)
            allow(deploy_job_mock).to receive(:branch)
            allow(deploy_job_mock).to receive(:cluster)
            allow(deploy_job_mock).to receive(:service)

            expect { bot.detect_github_event(deploy_job: deploy_job_mock) }.not_to raise_error
          end
        end

        describe 'detect_slack_deploy' do
          let(:deploy_job_mock) { double(DeployJob) }

          it 'should be not error' do
            allow(deploy_job_mock).to receive(:id)
            allow(deploy_job_mock).to receive(:repository)
            allow(deploy_job_mock).to receive(:account)
            allow(deploy_job_mock).to receive(:branch)
            allow(deploy_job_mock).to receive(:tag)
            allow(deploy_job_mock).to receive(:cluster)
            allow(deploy_job_mock).to receive(:service)
            allow(deploy_job_mock).to receive(:scheduled_task_rule)

            expect { bot.detect_slack_deploy(deploy_job: deploy_job_mock) }.not_to raise_error
          end
        end

        describe 'finished_deploy' do
          let(:deploy_job_mock) { double(DeployJob) }

          it 'should be not error' do
            allow(deploy_job_mock).to receive(:mode)
            allow(deploy_job_mock).to receive(:tag)
            allow(deploy_job_mock).to receive(:account)
            allow(deploy_job_mock).to receive(:repository)
            allow(deploy_job_mock).to receive(:slack_user_id)
            allow(deploy_job_mock).to receive(:task_definition_arns).and_return([])

            expect { bot.finished_deploy(deploy_job: deploy_job_mock) }.not_to raise_error
          end
        end

        describe 'error' do
          it 'should be not error' do
            expect { bot.error(error: Genova::Exceptions::Error.new) }.not_to raise_error
          end
        end
      end
    end
  end
end
