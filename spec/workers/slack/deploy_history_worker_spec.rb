require 'rails_helper'

module Slack
  describe DeployHistoryWorker do
    describe 'perform' do
      let(:parent_message_ts) { Time.now.utc.to_f }
      let(:session_store) { double(Genova::Slack::SessionStore) }
      let(:bot) { double(Genova::Slack::Interactive::Bot) }

      before do
        allow(Genova::Slack::SessionStore).to receive(:load).and_return(session_store)
        allow(session_store).to receive(:params).and_return(repository: 'repository')

        allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)
        allow(bot).to receive(:ask_confirm_deploy)

        subject.perform(parent_message_ts)
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
