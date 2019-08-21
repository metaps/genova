require 'rails_helper'

module Slack
  describe DeployWorker do
    describe 'perform' do
      let(:id) do
        deploy_job = DeployJob.new(
          mode: DeployJob.mode.find_value(:manual),
          type: DeployJob.type.find_value(:service),
          repository: 'repository',
          cluster: 'cluster',
          service: 'service'
        )
        deploy_job.save!
        deploy_job.id
      end
      let(:bot_mock) { double(Genova::Slack::Bot) }
      let(:genova_client_mock) { double(Genova::Client) }

      before do
        DeployJob.collection.drop

        allow(bot_mock).to receive(:post_detect_slack_deploy)
        allow(bot_mock).to receive(:post_started_deploy)
        allow(bot_mock).to receive(:post_finished_deploy)
        allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)

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
