require 'rails_helper'

module Slack
  describe InteractionWorker do
    describe 'perform' do
      let(:key) { Genova::Sidekiq::JobStore.create('message_ts:message_ts', foo: 'bar') }

      before do
        remove_key = Genova::Sidekiq::JobStore.send(:generate_key, 'message_ts:message_ts')
        Genova::RedisPool.get.del(remove_key)

        allow(Genova::Slack::RequestHandler).to receive(:call)
        subject.perform(key)
      end

      it 'should in queue' do
        is_expected.to be_processed_in(:slack_interaction)
      end

      it 'should no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
