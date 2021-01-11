require 'rails_helper'

module Slack
  describe DeployTargetWorker do
    describe 'perform' do
      let(:bot_mock) { double(Genova::Slack::Bot) }

      before do
        Redis.current.flushdb

        allow(bot_mock).to receive(:post_choose_target)
        allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)

        Genova::Slack::SessionStore.new('user').start
        subject.perform('user')
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
