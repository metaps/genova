require 'rails_helper'

module Slack
  describe DeployWorker do
    describe 'perform' do
      let(:deploy_job_id) do
        deploy_job = DeployJob.new(
          mode: DeployJob.mode.find_value(:manual),
          type: DeployJob.type.find_value(:service),
          account: Settings.github.account,
          repository: 'repository',
          cluster: 'cluster',
          service: 'service',
          slack_user_id: 'slack_user_id'
        )
        deploy_job.save
      end
      let(:bot) { double(Genova::Slack::Interactive::Bot) }
      let(:client) { double(Slack::Web::Client) }
      let(:runner) { double(Genova::Deploy::Runner) }

      include_context :session_start

      before do
        DeployJob.collection.drop

        session_store.merge({
                              deploy_job_id:,
                              repository: 'repository',
                              cluster: 'cluster',
                              type: DeployJob.type.find_value(:service)
                            })

        allow(bot).to receive(:detect_slack_deploy)
        allow(client).to receive(:ts)
        allow(bot).to receive(:show_stop_button).and_return(client)
        allow(bot).to receive(:complete_deploy)
        allow(bot).to receive(:delete_message)
        allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)
      end

      context 'when job was successful' do
        before do
          allow(runner).to receive(:run)
          allow(Genova::Deploy::Runner).to receive(:new).and_return(runner)
          subject.perform(id)
        end

        it 'should in queeue' do
          is_expected.to be_processed_in(:slack_deploy)
        end

        it 'should no retry' do
          is_expected.to be_retryable(false)
        end
      end

      context 'when job failed' do
        before do
          allow(runner).to receive(:run).and_raise(Genova::Exceptions::ImageBuildError)
          allow(Genova::Deploy::Runner).to receive(:new).and_return(runner)
        end

        it 'shouold be notify Slack of errors' do
          allow(subject).to receive(:send_error)

          expect { subject.perform(id) }.to raise_error(Genova::Exceptions::ImageBuildError)
          expect(subject).to have_received(:send_error).once
        end
      end
    end
  end
end
