require 'rails_helper'

module Slack
  describe DeployConfirmWorker do
    describe 'perform' do
      let(:bot) { double(Genova::Slack::Interactive::Bot) }

      include_context :session_start

      before do
        allow(bot).to receive(:ask_confirm_deploy)
        allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)

        subject.perform(id)
      end

      it 'should in queue' do
        is_expected.to be_processed_in(:slack_deploy_confirm)
      end

      it 'should no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
