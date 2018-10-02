require 'rails_helper'

module Genova
  module Slack
    describe Util do
      describe 'history_options' do
        let(:deploy_job) do
          DeployJob.create(
            id: DeployJob.generate_id,
            status: DeployJob.status.find_value(:in_progress).to_s,
            mode: DeployJob.mode.find_value(:auto).to_s,
            account: 'account',
            repository: 'repository',
            branch: 'branch',
            cluster: 'cluster',
            service: 'service'
          )
        end

        before do
          Redis.current.flushdb
          DeployJob.delete_all
        end

        it 'should be return histories' do
          Genova::Slack::History.new('slack_user_id').add(deploy_job)

          results = Genova::Slack::Util.history_options('slack_user_id')

          expect(results.count).to eq(1)
          expect(results[0][:text]).to eq(deploy_job.id)
          expect(results[0][:value]).to eq(deploy_job.id)
          expect(results[0][:description]).to eq("#{deploy_job.repository} (#{deploy_job.branch})")
        end
      end

      describe 'repository_options' do
        it 'should be return repositories' do
          results = Genova::Slack::Util.repository_options

          expect(results.count).to eq(1)
          expect(results[0][:text]).to eq('repository')
          expect(results[0][:value]).to eq('repository')
        end
      end

      describe 'branch_options' do
        include_context 'load repository_manager_mock'

        it 'should be return brahches' do
          results = Genova::Slack::Util.branch_options('account', 'repository')

          expect(results.count).to eq(1)
          expect(results[0][:text]).to eq('feature/branch')
          expect(results[0][:value]).to eq('feature/branch')
        end
      end

      describe 'cluster_options' do
        include_context 'load repository_manager_mock'

        it 'should be return clusters' do
          results = Genova::Slack::Util.cluster_options('account', 'repository', 'branch')

          expect(results.count).to eq(1)
          expect(results[0][:text]).to eq('cluster')
          expect(results[0][:value]).to eq('cluster')
        end
      end
    end
  end
end
