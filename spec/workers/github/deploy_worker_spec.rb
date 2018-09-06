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
      before do
        deploy_job_id = create_deploy_job(
          account: 'account',
          repository: 'repository',
          branch: 'branch',
          cluster: 'cluster',
          service: 'service'
        )
        subject.perform(deploy_job_id)
      end

      it 'should be in queue' do
        is_expected.to be_processed_in(:auto_deploy)
      end

      it 'should be no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
