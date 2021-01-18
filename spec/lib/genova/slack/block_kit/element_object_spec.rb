require 'rails_helper'

module Genova
  module Slack
    module BlockKit
      describe ElementObject do
        before do
          Redis.current.flushdb
          DeployJob.delete_all
        end

        describe 'repository_options' do
          it 'should be return repositories' do
            results = Genova::Slack::BlockKit::ElementObject.repository_options

            expect(results.count).to eq(1)
          end
        end

        describe 'history_options' do
          let(:history_mock) { double(Genova::Slack::Interactive::History) }

          it 'should be return histories' do
            allow(history_mock).to receive(:list).and_return([Oj.dump(
              id: Time.now.utc.strftime('%Y%m%d-%H%M%S'),
              repository: 'repository',
              branch: 'branch',
              cluster: 'cluster'
            )])
            allow(Genova::Slack::Interactive::History).to receive(:new).and_return(history_mock)

            results = Genova::Slack::BlockKit::ElementObject.history_options('user')
            expect(results.count).to eq(1)
          end
        end

        describe 'branch_options' do
          let(:code_manager_mock) { double(Genova::CodeManager::Git) }

          it 'should be return brahches' do
            allow(code_manager_mock).to receive(:origin_branches).and_return(['branch'])
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager_mock)

            results = Genova::Slack::BlockKit::ElementObject.branch_options('account', 'repository')
            expect(results.count).to eq(1)
          end
        end

        describe 'tag_options' do
          let(:code_manager_mock) { double(Genova::CodeManager::Git) }

          it 'should be return tags' do
            allow(code_manager_mock).to receive(:origin_tags).and_return(['tag'])
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager_mock)

            results = Genova::Slack::BlockKit::ElementObject.tag_options('account', 'repository')
            expect(results.count).to eq(1)
          end
        end

        describe 'cluster_options' do
          let(:code_manager_mock) { double(Genova::CodeManager::Git) }

          it 'should be return clusters' do
            allow(code_manager_mock).to receive(:load_deploy_config).and_return(
              clusters: [
                {
                  name: 'cluster'
                }
              ]
            )
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager_mock)

            results = Genova::Slack::BlockKit::ElementObject.cluster_options('account', 'repository', 'branch', 'tag', 'base_path')

            expect(results.count).to eq(1)
          end
        end

        describe 'target_options' do
          let(:code_manager_mock) { double(Genova::CodeManager::Git) }
          let(:deploy_config_mock) { double(Genova::Config::DeployConfig) }

          it 'should be return targets' do
            allow(deploy_config_mock).to receive(:cluster).and_return(
              run_tasks: {
                run_task: nil
              },
              services: {
                service: nil
              },
              scheduled_tasks: [
                {
                  rule: 'rule',
                  targets: [
                    {
                      name: 'name'
                    }
                  ]
                }
              ]
            )
            allow(code_manager_mock).to receive(:load_deploy_config).and_return(deploy_config_mock)
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager_mock)

            results = Genova::Slack::BlockKit::ElementObject.target_options('account', 'repository', 'branch', 'tag', 'cluster', 'base_path')
            expect(results.count).to eq(3)
          end
        end
      end
    end
  end
end
