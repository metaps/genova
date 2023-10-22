require 'rails_helper'

module Genova
  module Slack
    module Interactive
      describe History do
        let(:history) { Genova::Slack::Interactive::History.new('user_id') }

        before do
          Genova::RedisPool.get.flushdb
          allow(Settings.slack.command).to receive(:max_history).and_return(2)
        end

        describe 'add' do
          context 'when adding key for first' do
            let(:deploy_job) do
              DeployJob.new(
                id: DeployJob.generate_id,
                account: 'metaps',
                repository: 'genova',
                branch: 'master',
                cluster: 'default'
              )
            end

            it 'should return one history' do
              history.add(deploy_job)
              expect(history.list.size).to eq(1)
            end
          end

          context 'when adding key for second (new key)' do
            let(:deploy_job_1) do
              DeployJob.new(
                id: DeployJob.generate_id,
                account: 'metaps',
                repository: 'genova',
                branch: 'master',
                cluster: 'default',
                service: 'development'
              )
            end
            let(:deploy_job_2) do
              DeployJob.new(
                id: DeployJob.generate_id,
                account: 'metaps',
                repository: 'genova',
                branch: 'master',
                cluster: 'default',
                service: 'production'
              )
            end
            it 'should return two history' do
              history.add(deploy_job_1)
              history.add(deploy_job_2)

              expect(history.list.size).to eq(2)
            end
          end

          context 'when adding key for second (exist key)' do
            let(:deploy_job) do
              DeployJob.new(
                id: DeployJob.generate_id,
                account: 'metaps',
                repository: 'genova',
                branch: 'master',
                cluster: 'default',
                service: 'production'
              )
            end

            it 'should return one history' do
              history.add(deploy_job)
              history.add(deploy_job)

              expect(history.list.size).to eq(1)
            end
          end

          context 'when history holdings is exceeded' do
            let(:deploy_job_1) do
              DeployJob.new(
                id: DeployJob.generate_id,
                account: 'metaps',
                repository: 'genova',
                branch: 'feature/3',
                cluster: 'default',
                service: 'development'
              )
            end
            let(:deploy_job_2) do
              DeployJob.new(
                id: DeployJob.generate_id,
                account: 'metaps',
                repository: 'genova',
                branch: 'feature/2',
                cluster: 'default',
                service: 'development'
              )
            end
            let(:deploy_job_3) do
              DeployJob.new(
                id: DeployJob.generate_id,
                account: 'metaps',
                repository: 'genova',
                branch: 'feature/1',
                cluster: 'default',
                service: 'development'
              )
            end
            it 'should delete old history' do
              history.add(deploy_job_1)
              history.add(deploy_job_2)
              history.add(deploy_job_3)

              expect(history.list.size).to eq(2)
            end
          end
        end

        describe 'last' do
          context 'when adding key for first' do
            let(:deploy_job) do
              DeployJob.new(
                id: DeployJob.generate_id,
                account: 'metaps',
                repository: 'genova',
                branch: 'master',
                cluster: 'default',
                service: 'development'
              )
            end
            it 'should return last value' do
              history.add(deploy_job)
              last = history.last

              expect(last[:account]).to eq('metaps')
              expect(last[:repository]).to eq('genova')
              expect(last[:branch]).to eq('master')
              expect(last[:cluster]).to eq('default')
              expect(last[:service]).to eq('development')
            end
          end

          context 'when adding key for second (first key)' do
            let(:deploy_job_1) do
              DeployJob.new(
                id: DeployJob.generate_id,
                account: 'metaps',
                repository: 'genova',
                branch: 'master',
                cluster: 'default',
                service: 'development'
              )
            end
            let(:deploy_job_2) do
              DeployJob.new(
                id: DeployJob.generate_id,
                account: 'metaps',
                repository: 'genova',
                branch: 'master',
                cluster: 'default',
                service: 'production'
              )
            end

            it 'should return last value' do
              history.add(deploy_job_1)
              history.add(deploy_job_2)

              last = history.last

              expect(last[:account]).to eq('metaps')
              expect(last[:repository]).to eq('genova')
              expect(last[:branch]).to eq('master')
              expect(last[:service]).to eq('production')
            end
          end
        end
      end
    end
  end
end
