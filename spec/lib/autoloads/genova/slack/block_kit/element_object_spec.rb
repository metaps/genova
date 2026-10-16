require 'rails_helper'

module Genova
  module Slack
    module BlockKit
      describe ElementObject do
        after do
          Settings.reload_from_files(Rails.root.join('config', 'settings.yml').to_s)
          Genova::RedisPool.get.flushdb
          DeployJob.delete_all
        end

        describe 'repository_options' do
          it 'should return repositories' do
            Settings.add_source!(
              github: {
                repositories: [{
                  name: 'repository'
                }]
              }
            )
            Settings.reload!

            results = Genova::Slack::BlockKit::ElementObject.repository_options({})
            expect(results.count).to eq(1)
          end
        end

        describe 'history_options' do
          let(:history) { double(Genova::Slack::Interactive::History) }

          it 'should return histories' do
            allow(history).to receive(:list).and_return([Oj.dump(
              id: Time.now.utc.strftime('%Y%m%d-%H%M%S'),
              repository: 'repository',
              branch: 'branch',
              cluster: 'cluster'
            )])
            allow(Genova::Slack::Interactive::History).to receive(:new).and_return(history)

            results = Genova::Slack::BlockKit::ElementObject.history_options(user: 'user')
            expect(results.count).to eq(1)
          end
        end

        describe 'branch_options' do
          let(:code_manager) { double(Genova::CodeManager::Git) }

          it 'should return brahches' do
            allow(code_manager).to receive(:default_branch)
            allow(code_manager).to receive(:origin_branches).and_return(['branch'])
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager)

            results = Genova::Slack::BlockKit::ElementObject.branch_options(account: 'account', repository: 'repository')
            expect(results.count).to eq(1)
          end

          it 'should build option groups from a given branch list without fetching' do
            allow(Genova::CodeManager::Git).to receive(:new)

            results = Genova::Slack::BlockKit::ElementObject.branch_option_groups(%w[main release], 'release')

            expect(results[0][:options]).to eq([Genova::Slack::BlockKit::ElementObject.branch_option('release')])
            expect(results[1][:options].pluck(:value)).to eq(%w[main])
            expect(Genova::CodeManager::Git).to_not have_received(:new)
          end

          it 'should not exceed the number of options Slack accepts' do
            branches = Array.new(200) { |i| "branch#{i}" }

            results = Genova::Slack::BlockKit::ElementObject.branch_option_groups(branches, 'default')
            total = results.sum { |group| group[:options].size }

            expect(total).to eq(Genova::Slack::BlockKit::ElementObject::MAX_SELECT_OPTIONS)
          end
        end

        describe 'tag_options' do
          let(:code_manager) { double(Genova::CodeManager::Git) }

          it 'should return tags' do
            allow(code_manager).to receive(:origin_tags).and_return(['tag'])
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager)

            results = Genova::Slack::BlockKit::ElementObject.tag_options(account: 'account', repository: 'repository')
            expect(results.count).to eq(1)
          end
        end

        describe 'cluster_options' do
          let(:code_manager) { double(Genova::CodeManager::Git) }

          it 'should return clusters' do
            allow(code_manager).to receive(:update)
            allow(code_manager).to receive(:deploy_config).and_return(
              clusters: [
                {
                  name: 'cluster'
                }
              ]
            )
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager)

            results = Genova::Slack::BlockKit::ElementObject.cluster_options(
              acount: 'account',
              repository: 'repository',
              alias: 'alias',
              branch: 'branch',
              tag: 'tag'
            )

            expect(results.count).to eq(1)
            expect(Genova::CodeManager::Git).to have_received(:new).with('repository', alias: 'alias', branch: 'branch', tag: 'tag')
          end
        end

        describe 'target_options' do
          let(:code_manager) { double(Genova::CodeManager::Git) }
          let(:deploy_config) { double(Genova::Config::DeployConfig) }
          let(:params) do
            {
              account: 'account',
              repository: 'repository',
              branch: 'branch',
              tag: 'tag',
              cluster: 'cluster'
            }
          end

          it 'should return targets' do
            allow(code_manager).to receive(:update)
            allow(deploy_config).to receive(:find_cluster).and_return(
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
            allow(code_manager).to receive(:deploy_config).and_return(deploy_config)
            allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager)

            service_options = Genova::Slack::BlockKit::ElementObject.service_options(params)
            run_task_options = Genova::Slack::BlockKit::ElementObject.run_task_options(params)
            scheduled_task_options = Genova::Slack::BlockKit::ElementObject.scheduled_task_options(params)

            expect(service_options.count + run_task_options.size + scheduled_task_options.size).to eq(3)
          end
        end
      end
    end
  end
end
