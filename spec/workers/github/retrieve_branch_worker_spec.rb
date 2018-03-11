require 'rails_helper'

module Github
  describe RetrieveBranchWorker do
    describe 'perform' do
      before do
        allow(Genova::Slack::Util).to receive(:branch_options)
        allow(RestClient).to receive(:post)

        subject.perform('account', 'repository', 'response_url')
      end

      it 'shuold be in queeue' do
        is_expected.to be_processed_in(:detect_branches)
      end

      it 'shuold be no retry' do
        is_expected.to be_retryable(false)
      end

      it 'shuold be call slack api' do
        expect(RestClient).to have_received(:post).once
      end
    end
  end
end
