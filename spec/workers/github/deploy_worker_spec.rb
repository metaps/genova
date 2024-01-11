require 'rails_helper'

module Github
  describe DeployWorker do
    include ::V2::Helper::GithubHelper

    let(:key) do
      Genova::Sidekiq::JobStore.create(
        'pushed_at:pushed_at', {
          account: 'account',
          repository: 'repository',
          branch: 'branch'
        }
      )
    end
    let(:code_manager) { double(Genova::CodeManager::Git) }
    let(:deploy_config) do
      Genova::Config::DeployConfig.new(
        auto_deploy: [{
          branch: 'branch',
          steps: [{
            type: 'service',
            cluster: 'cluster',
            resources: ['service']
          }]
        }],
        clusters: []
      )
    end
    let(:bot) { double(Genova::Slack::Interactive::Bot) }
    let(:client) { double(Slack::Web::Client) }
    let(:remove_key) { Genova::Sidekiq::JobStore.send(:generate_key, 'pushed_at:pushed_at') }
    let(:runner) { double(Genova::Deploy::Runner) }
    let(:chat) { double(::Slack::Web::Api::Endpoints::Chat) }

    before do
      DeployJob.delete_all
      Genova::RedisPool.get.del(remove_key)

      allow(client).to receive(:ts)

      allow(bot).to receive(:detect_auto_deploy).and_return(client)
      allow(bot).to receive(:start_step)
      allow(bot).to receive(:start_deploy)
      allow(bot).to receive(:complete_deploy)
      allow(bot).to receive(:complete_steps)

      allow(chat).to receive(:ts)
      allow(bot).to receive(:show_stop_button).and_return(chat)
      allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)
      allow(bot).to receive(:delete_message)

      allow(code_manager).to receive(:deploy_config).and_return(deploy_config)
      allow(code_manager).to receive(:update)
      allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager)

      allow(runner).to receive(:run)
      allow(Genova::Deploy::Runner).to receive(:new).and_return(runner)
    end

    describe 'perform' do
      before do
        subject.perform(key)
      end

      it 'should in queue' do
        is_expected.to be_processed_in(:github_deploy)
      end

      it 'should no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
