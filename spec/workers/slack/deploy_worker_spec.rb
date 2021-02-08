require 'rails_helper'

module Slack
  describe DeployWorker do
    describe 'perform' do
      let(:deploy_job_id) do
        deploy_job = DeployJob.new(
          mode: DeployJob.mode.find_value(:manual),
          type: DeployJob.type.find_value(:service),
          account: ENV.fetch('GITHUB_ACCOUNT'),
          repository: 'repository',
          cluster: 'cluster',
          service: 'service',
          slack_user_id: 'slack_user_id'
        )
        deploy_job.save!
        deploy_job.id
      end
      let(:bot_mock) { double(Genova::Slack::Interactive::Bot) }
      let(:genova_client_mock) { double(Genova::Client) }

      include_context :session_start

      before do
        DeployJob.collection.drop

        session_store.save(deploy_job_id: deploy_job_id)

        allow(bot_mock).to receive(:detect_slack_deploy)
        allow(bot_mock).to receive(:finished_deploy)
        allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot_mock)

        allow(genova_client_mock).to receive(:run)
        allow(Genova::Client).to receive(:new).and_return(genova_client_mock)

        subject.perform(id)
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
