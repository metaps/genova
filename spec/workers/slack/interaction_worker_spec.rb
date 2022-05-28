require 'rails_helper'

module Slack
  describe InteractionWorker do
    describe 'perform' do
      let(:key) { Genova::Sidekiq::JobStore.create('message_ts:message_ts', foo: 'bar') }

      before do
        remove_key = Genova::Sidekiq::JobStore.send(:generate_key, 'message_ts:message_ts')
        Redis.current.del(remove_key)

        allow(Genova::Slack::RequestHandler).to receive(:call)
        subject.perform(key)
      end

      it 'should be in queeue' do
        is_expected.to be_processed_in(:slack_interaction)
      end

      it 'should be no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
