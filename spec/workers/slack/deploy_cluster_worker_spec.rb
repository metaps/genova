require 'rails_helper'

module Slack
  describe DeployClusterWorker do
    describe 'perform' do
      let(:id) { Genova::Sidekiq::Queue.add }
      let(:bot_mock) { double(Genova::Slack::Bot) }

      before do
        allow(bot_mock).to receive(:post_choose_cluster)
        allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)

        subject.perform(id)
      end

      it 'should be in queeue' do
        is_expected.to be_processed_in(:slack_deploy_cluster)
      end

      it 'should be no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
