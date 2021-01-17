require 'rails_helper'

module Slack
  describe DeployHistoryWorker do
    describe 'perform' do
      let(:session_store_mock) { double(Genova::Slack::SessionStore) }
      let(:bot_mock) { double(Genova::Slack::Interactive::Bot) }

      before do
        allow(Genova::Slack::SessionStore).to receive(:new).and_return(session_store_mock)
        allow(session_store_mock).to receive(:params)

        allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot_mock)
        allow(bot_mock).to receive(:post_confirm_deploy)

        subject.perform('id')
      end

      it 'should be in queeue' do
        is_expected.to be_processed_in(:slack_deploy_history)
      end

      it 'should be no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
