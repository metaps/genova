require 'rails_helper'

module Slack
  describe DeployWorker do
    describe 'perform' do
      before do
        deploy_job_mock = DeployJob.new(
          repository: 'repository',
          account: 'account',
          branch: 'branch',
          cluster: 'cluster',
          service: 'service',
          slack_user_id: 'slack_user_id'
        )
        allow(DeployJob).to receive(:find).and_return(deploy_job_mock)

        bot_mock = double(Genova::Slack::Bot)
        allow(bot_mock).to receive(:post_detect_slack_deploy)
        allow(bot_mock).to receive(:post_started_deploy)
        allow(bot_mock).to receive(:post_finished_deploy)
        allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)

        deploy_client_mock = double(Genova::Client)
        allow(deploy_client_mock).to receive(:run)
        allow(Genova::Client).to receive(:new).and_return(deploy_client_mock)

        subject.perform('deploy_job_id')
      end

      it 'should be in queeue' do
        is_expected.to be_processed_in(:slack_deploy)
      end

      it 'should be no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
