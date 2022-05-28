require 'rails_helper'

module Github
  describe DeployWorker do
    include ::V2::Helper::GithubHelper

    let(:key) do
      Genova::Sidekiq::JobStore.create(
        'pushed_at', {
          account: 'account',
          repository: 'repository',
          branch: 'branch'
        }
      )
    end
    let(:code_manager_mock) { double(Genova::CodeManager::Git) }
    let(:deploy_config_mock) do
      Genova::Config::DeployConfig.new(
        auto_deploy: [{
          branch: 'branch',
          steps: [{
            type: 'service',
            cluster: 'cluster',
            resources: ['service']
          }]
        }],
        clusters: []
      )
    end
    let(:slack_bot_mock) { double(Genova::Slack::Interactive::Bot) }

    before(:each) do
      DeployJob.delete_all

      key = Genova::Sidekiq::JobStore.send(:generate_key, 'pushed_at')
      Redis.current.del(key)

      allow(code_manager_mock).to receive(:load_deploy_config).and_return(deploy_config_mock)
      allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager_mock)

      allow(slack_bot_mock).to receive(:detect_auto_deploy).and_return(parent_message_ts: Time.now.utc.to_f)
      allow(slack_bot_mock).to receive(:start_auto_deploy_step)
      allow(slack_bot_mock).to receive(:start_auto_deploy_run)
      allow(slack_bot_mock).to receive(:finished_deploy)
      allow(slack_bot_mock).to receive(:finished_auto_deploy_all)
      allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(slack_bot_mock)

      allow(Genova::Run).to receive(:call)
    end

    describe 'perform' do
      before do
        subject.perform(key)
      end

      it 'should be in queue' do
        is_expected.to be_processed_in(:github_deploy)
      end

      it 'should be no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
