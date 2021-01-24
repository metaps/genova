require 'rails_helper'

module Slack
  describe DeployClusterWorker do
    describe 'perform' do
      let(:parent_message_ts) { Time.now.utc.to_f }
      let(:permission_mock) { double(Genova::Slack::Interactive::Permission) }
      let(:bot_mock) { double(Genova::Slack::Interactive::Bot) }

      before do
        Redis.current.flushdb
        Genova::Slack::SessionStore.start!(parent_message_ts, 'user')

        allow(Genova::Slack::Client).to receive(:get).and_return({
                                                                   ok: true,
                                                                   user: {
                                                                     name: 'user'
                                                                   }
                                                                 })
        allow(permission_mock).to receive(:allow_clusters).and_return(['cluster'])
        allow(Genova::Slack::Interactive::Permission).to receive(:new).and_return(permission_mock)
        allow(bot_mock).to receive(:ask_cluster)
        allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot_mock)

        subject.perform(parent_message_ts)
      end

      it 'should be in queeue' do
        is_expected.to be_processed_in(:slack_deploy_cluster)
      end

      it 'should be no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
