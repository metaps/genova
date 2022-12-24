require 'rails_helper'

module Slack
  describe DeployWorker do
    describe 'perform' do
      let(:deploy_job_id) do
        deploy_job = DeployJob.new(
          mode: DeployJob.mode.find_value(:manual),
          type: DeployJob.type.find_value(:service),
          account: Settings.github.account,
          repository: 'repository',
          cluster: 'cluster',
          service: 'service',
          slack_user_id: 'slack_user_id'
        )
        deploy_job.save
      end
      let(:bot_mock) { double(Genova::Slack::Interactive::Bot) }

      include_context :session_start

      before do
        DeployJob.collection.drop

        session_store.save(
          deploy_job_id: deploy_job_id,
          repository: 'repository',
          cluster: 'cluster',
          type: DeployJob.type.find_value(:service)
        )

        allow(bot_mock).to receive(:detect_slack_deploy)
        allow(bot_mock).to receive(:complete_deploy)
        allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot_mock)

        allow(Genova::Deploy::Runner).to receive(:call)

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
