require 'rails_helper'

module Github
  describe RetrieveBranchWorker do
    describe 'perform' do
      let(:bot_mock) { double(Genova::Slack::Interactive::Bot) }

      before do
        Redis.current.flushdb

        allow(bot_mock).to receive(:post_choose_branch)
        allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot_mock)

        Genova::Slack::SessionStore.new('user').start
        subject.perform('user')
      end

      it 'should be in queue' do
        is_expected.to be_processed_in(:github_retrieve_branch)
      end

      it 'should be no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
