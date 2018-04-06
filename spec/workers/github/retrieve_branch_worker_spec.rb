require 'rails_helper'

module Github
  describe RetrieveBranchWorker do
    describe 'perform' do
      before do
        allow(Genova::Slack::Util).to receive(:branch_options)
        allow(RestClient).to receive(:post)

        job = Genova::Sidekiq::Job.new(
          'id',
            account: 'account',
            repository: 'repository',
            response_url: 'response_url'
        )
        allow(Genova::Sidekiq::Queue).to receive(:find).and_return(job)
        subject.perform(job.id)
      end

      it 'should be in queue' do
        is_expected.to be_processed_in(:detect_branches)
      end

      it 'should be no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
