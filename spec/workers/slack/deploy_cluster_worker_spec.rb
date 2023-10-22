require 'rails_helper'

module Slack
  describe DeployClusterWorker do
    describe 'perform' do
      let(:bot) { double(Genova::Slack::Interactive::Bot) }

      include_context :session_start

      before do
        allow(bot).to receive(:ask_cluster)
        allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)

        subject.perform(id)
      end

      it 'should in queue' do
        is_expected.to be_processed_in(:slack_deploy_cluster)
      end

      it 'should no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
