require 'rails_helper'

module Slack
  describe DeployConfirmWorker do
    describe 'perform' do
      let(:id) { Time.now.utc.to_f }
      let(:parent_message_ts) { Time.now.utc.to_f }
      let(:bot_mock) { double(Genova::Slack::Interactive::Bot) }

      before do
        allow(bot_mock).to receive(:ask_confirm_deploy)
        allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot_mock)

        Genova::Slack::SessionStore.start!(parent_message_ts, 'user')
        subject.perform(parent_message_ts)
      end

      it 'should be in queeue' do
        is_expected.to be_processed_in(:slack_deploy_confirm)
      end

      it 'should be no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
