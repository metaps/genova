require 'rails_helper'

module Github
  describe DeployWorker do
    include ::V1::Helper::GithubHelper

    let(:slack_bot_mock) { double(Genova::Slack::Bot) }
    let(:client_mock) { double(Genova::Client) }

    before(:each) do
      DeployJob.delete_all

      allow(slack_bot_mock).to receive(:post_detect_auto_deploy)
      allow(slack_bot_mock).to receive(:post_started_deploy)
      allow(slack_bot_mock).to receive(:post_finished_deploy)
      allow(Genova::Slack::Bot).to receive(:new).and_return(slack_bot_mock)

      allow(client_mock).to receive(:run).and_return({})
      allow(Genova::Client).to receive(:new).and_return(client_mock)
    end

    describe 'perform' do
      include_context 'load code_manager_mock'

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
        subject.perform(deploy_job.id)
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
