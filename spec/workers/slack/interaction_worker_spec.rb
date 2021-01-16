require 'rails_helper'

module Slack
  describe InteractionWorker do
    describe 'perform' do
      let (:id) { Genova::Sidekiq::JobStore.create(foo: 'bar') }

      before do
        allow(Genova::Slack::RequestHandler).to receive(:handle_request)

        subject.perform(id)
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
