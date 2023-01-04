require 'rails_helper'

module Slack
  describe DeployTargetWorker do
    describe 'perform' do
      let(:bot) { double(Genova::Slack::Interactive::Bot) }

      include_context :session_start

      before do
        allow(bot).to receive(:ask_target)
        allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)

        subject.perform(id)
      end

      it 'should be in queeue' do
        is_expected.to be_processed_in(:slack_deploy_target)
      end

      it 'should be no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
