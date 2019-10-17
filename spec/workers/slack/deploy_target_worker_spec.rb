require 'rails_helper'

module Slack
  describe DeployTargetWorker do
    describe 'perform' do
      let(:id) { Genova::Sidekiq::Queue.add }
      let(:job_mock) { double(Genova::Sidekiq::Job) }
      let(:bot_mock) { double(Genova::Slack::Bot) }

      before do
        allow(job_mock).to receive(:account)
        allow(job_mock).to receive(:repository)
        allow(job_mock).to receive(:branch)
        allow(job_mock).to receive(:cluster)
        allow(job_mock).to receive(:base_path)

        allow(Genova::Sidekiq::Queue).to receive(:find).and_return(job_mock)

        allow(bot_mock).to receive(:post_choose_target)
        allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)

        subject.perform(id)
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
