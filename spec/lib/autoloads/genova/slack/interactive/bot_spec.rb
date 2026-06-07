require 'rails_helper'

module Genova
  module Slack
    module Interactive
      describe Bot do
        let(:bot) { Genova::Slack::Interactive::Bot.new }
        let(:client) { double(::Slack::Web::Client) }

        before do
          allow(::Slack::Web::Client).to receive(:new).and_return(client)
          allow(client).to receive(:chat_postMessage)
        end

        describe 'send_message' do
          it 'should not error' do
            expect { bot.send_message('message') }.not_to raise_error
          end
        end

        describe 'ask_history' do
          let(:array) { double(Array) }

          it 'should not error' do
            allow(array).to receive(:empty?).and_return(false)
            allow(BlockKit::ElementObject).to receive(:history_options).and_return(array)

            expect { bot.ask_history({}) }.not_to raise_error
          end
        end

        describe 'ask_repository' do
          let(:array) { double(Array) }

          it 'should not error' do
            allow(BlockKit::ElementObject).to receive(:repository_options).and_return([array])

            expect { bot.ask_repository({}) }.not_to raise_error
          end
        end

        describe 'ask_branch' do
          let(:array) { double(Array) }

          it 'should not error' do
            allow(array).to receive(:size).and_return(1)
            allow(BlockKit::ElementObject).to receive(:branch_options)
            allow(BlockKit::ElementObject).to receive(:tag_options).and_return(array)

            expect { bot.ask_branch({}) }.not_to raise_error
          end
        end

        describe 'ask_cluster' do
          let(:array) { double(Array) }

          it 'should not error' do
            allow(array).to receive(:empty?).and_return(false)
            allow(BlockKit::ElementObject).to receive(:cluster_options).and_return(array)

            expect { bot.ask_cluster({}) }.not_to raise_error
          end
        end

        describe 'ask_target' do
          let(:array) { double(Array) }

          it 'should not error' do
            allow(array).to receive(:empty?).and_return(false)
            allow(array).to receive(:size).and_return(1)
            allow(BlockKit::ElementObject).to receive(:run_task_options).and_return(array)
            allow(BlockKit::ElementObject).to receive(:service_options).and_return(array)
            allow(BlockKit::ElementObject).to receive(:scheduled_task_options).and_return(array)

            expect { bot.ask_target({}) }.not_to raise_error
          end
        end

        describe 'ask_confirm_deploy' do
          let(:params) do
            {
              service: 'service'
            }
          end
          let(:code_manager) { double(Genova::CodeManager::Git) }
          let(:ecs_client) { double(Aws::ECS::Client) }
          let(:describe_services_response) { double(Aws::ECS::Types::DescribeServicesResponse) }
          let(:service) { double(Aws::ECS::Types::Service) }
          let(:describe_task_definition_response) { double(Aws::ECS::Types::DescribeTaskDefinitionResponse) }

          it 'should not error' do
            allow(code_manager).to receive(:origin_last_commit).and_return('xxx')
            allow(code_manager).to receive(:find_commit).and_return('yyy')
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager)
            allow(Aws::ECS::Client).to receive(:new).and_return(ecs_client)
            allow(describe_services_response).to receive(:services).and_return([service])
            allow(ecs_client).to receive(:describe_services).and_return(describe_services_response)
            allow(service).to receive(:task_definition)
            allow(describe_task_definition_response).to receive(:[]).with(:tags).and_return([{
                                                                                              key: 'genova.build'
                                                                                            }])
            allow(ecs_client).to receive(:describe_task_definition).and_return(describe_task_definition_response)

            expect { bot.ask_confirm_deploy(params, show_target: true) }.not_to raise_error
          end

          it 'uses multiline note input when note is absent' do
            allow(code_manager).to receive(:origin_last_commit).and_return('xxx')
            allow(code_manager).to receive(:find_commit).and_return('yyy')
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager)
            allow(Aws::ECS::Client).to receive(:new).and_return(ecs_client)
            allow(describe_services_response).to receive(:services).and_return([service])
            allow(ecs_client).to receive(:describe_services).and_return(describe_services_response)
            allow(service).to receive(:task_definition)
            allow(describe_task_definition_response).to receive(:[]).with(:tags).and_return([{ key: 'genova.build' }])
            allow(ecs_client).to receive(:describe_task_definition).and_return(describe_task_definition_response)

            expect(client).to receive(:chat_postMessage) do |data|
              note_block = data[:blocks].find { |block| block[:block_id] == 'deploy_note' }
              expect(note_block[:element][:multiline]).to eq(true)
            end

            bot.ask_confirm_deploy(params, show_target: false)
          end

          it 'uses full-width section when note is present' do
            allow(code_manager).to receive(:origin_last_commit).and_return('xxx')
            allow(code_manager).to receive(:find_commit).and_return('yyy')
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager)
            allow(Aws::ECS::Client).to receive(:new).and_return(ecs_client)
            allow(describe_services_response).to receive(:services).and_return([service])
            allow(ecs_client).to receive(:describe_services).and_return(describe_services_response)
            allow(service).to receive(:task_definition)
            allow(describe_task_definition_response).to receive(:[]).with(:tags).and_return([{ key: 'genova.build' }])
            allow(ecs_client).to receive(:describe_task_definition).and_return(describe_task_definition_response)

            expect(client).to receive(:chat_postMessage) do |data|
              note_block = data[:blocks].find do |block|
                block[:type] == 'section' && block.dig(:text, :text)&.include?('*Note:*')
              end
              expect(note_block[:fields]).to be_nil
              expect(note_block.dig(:text, :text)).to include("line1\nline2")
            end

            bot.ask_confirm_deploy(params.merge(note: "line1\nline2"), show_target: false)
          end

          it 'escapes mrkdwn in note before sending to Slack' do
            allow(code_manager).to receive(:origin_last_commit).and_return('xxx')
            allow(code_manager).to receive(:find_commit).and_return('yyy')
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager)
            allow(Aws::ECS::Client).to receive(:new).and_return(ecs_client)
            allow(describe_services_response).to receive(:services).and_return([service])
            allow(ecs_client).to receive(:describe_services).and_return(describe_services_response)
            allow(service).to receive(:task_definition)
            allow(describe_task_definition_response).to receive(:[]).with(:tags).and_return([{ key: 'genova.build' }])
            allow(ecs_client).to receive(:describe_task_definition).and_return(describe_task_definition_response)

            expect(client).to receive(:chat_postMessage) do |data|
              note_block = data[:blocks].find do |block|
                block[:type] == 'section' && block.dig(:text, :text)&.include?('*Note:*')
              end
              expect(note_block.dig(:text, :text)).to include('&lt;img src="test"&gt;')
            end

            bot.ask_confirm_deploy(params.merge(note: '<img src="test">'), show_target: false)
          end
        end

        describe 'detect_auto_deploy' do
          let(:params) do
            {
              account: 'account',
              repository: 'repository',
              branch: 'branch',
              commit_url: 'commit_url',
              author: 'author',
              cluster: 'cluster',
              services: ['service']
            }
          end

          it 'should not error' do
            expect { bot.detect_auto_deploy(params) }.not_to raise_error
          end
        end

        describe 'detect_slack_deploy' do
          let(:deploy_job) { double(DeployJob) }

          it 'should not error' do
            allow(deploy_job).to receive(:id)
            allow(deploy_job).to receive(:repository)
            allow(deploy_job).to receive(:account)
            allow(deploy_job).to receive(:branch)
            allow(deploy_job).to receive(:tag)
            allow(deploy_job).to receive(:cluster)
            allow(deploy_job).to receive(:service)
            allow(deploy_job).to receive(:scheduled_task_rule)

            expect { bot.detect_slack_deploy(deploy_job:) }.not_to raise_error
          end
        end

        describe 'complete_deploy' do
          let(:deploy_job) { double(DeployJob) }

          it 'should not error' do
            allow(deploy_job).to receive(:mode)
            allow(deploy_job).to receive(:tag)
            allow(deploy_job).to receive(:account)
            allow(deploy_job).to receive(:repository)
            allow(deploy_job).to receive(:slack_user_id)
            allow(deploy_job).to receive(:task_definition_arn).and_return('task_definition_arn')
            allow(deploy_job).to receive(:task_arns).and_return(['task_arn'])

            expect { bot.complete_deploy(deploy_job:) }.not_to raise_error
          end
        end

        describe 'error' do
          it 'should not error' do
            expect { bot.error(error: Genova::Exceptions::Error.new) }.not_to raise_error
          end
        end
      end
    end
  end
end
