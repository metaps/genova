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
    let(:slack_bot_mock) { double(Genova::Slack::Bot) }
    let(:client_mock) { double(Genova::Client) }

    before(:each) do
      DeployJob.delete_all

      allow(slack_bot_mock).to receive(:post_detect_auto_deploy)
      allow(slack_bot_mock).to receive(:post_started_deploy)
      allow(slack_bot_mock).to receive(:post_finished_deploy)
      allow(Genova::Slack::Bot).to receive(:new).and_return(slack_bot_mock)

      allow(client_mock).to receive(:run)
      allow(Genova::Client).to receive(:new).and_return(client_mock)
    end

    describe 'perform' do
      include_context 'load code_manager_mock'

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
