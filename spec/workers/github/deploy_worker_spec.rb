require 'rails_helper'

module Github
  describe DeployWorker do
    include ::V2::Helper::GithubHelper

    let(:id) do
      Genova::Sidekiq::JobStore.create(
        account: 'account',
        repository: 'repository',
        branch: 'branch'
      )
    end
    let(:code_manager_mock) { double(Genova::CodeManager::Git) }
    let(:deploy_config_mock) do
      Genova::Config::DeployConfig.new(
        auto_deploy: [{
          cluster: 'cluster',
          service: 'service',
          branch: 'branch'
        }],
        clusters: []
      )
    end
    let(:slack_bot_mock) { double(Genova::Slack::Interactive::Bot) }
    let(:client_mock) { double(Genova::Client) }

    before(:each) do
      DeployJob.delete_all

      allow(code_manager_mock).to receive(:load_deploy_config).and_return(deploy_config_mock)
      allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager_mock)

      allow(slack_bot_mock).to receive(:detect_github_event)
      allow(slack_bot_mock).to receive(:finished_deploy)
      allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(slack_bot_mock)

      allow(client_mock).to receive(:run)
      allow(Genova::Client).to receive(:new).and_return(client_mock)
    end

    describe 'perform' do
      before do
        subject.perform(id)
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
