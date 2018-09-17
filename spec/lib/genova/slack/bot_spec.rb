require 'rails_helper'

module Genova
  module Slack
    describe Bot do
      let(:bot) { Genova::Slack::Bot.new }
      let(:slack_web_client_mock) { double('::Slack::Web::Client') }

      before do
        Redis.current.flushdb

        allow(::Slack::Web::Client).to receive(:new).and_return(slack_web_client_mock)
        allow(slack_web_client_mock).to receive(:chat_postMessage)
      end

      describe 'initialize' do
        it 'should be return instance' do
          expect(bot).to be_a(Genova::Slack::Bot)
        end
      end

      describe 'post_choose_target' do
        it 'should be not error' do
          allow(Genova::Slack::Util).to receive(:target_options).and_return([])
          expect { bot.post_choose_target({}) }.not_to raise_error
        end
      end

      describe 'post_confirm_deploy' do
        it 'should be not error' do
          allow(bot).to receive(:git_latest_commit_id)
          allow(bot).to receive(:git_deployed_commit_id)

          expect { bot.post_confirm_deploy({}) }.not_to raise_error
        end
      end

      describe 'post_deploy_queue' do
        it 'should be call bot' do
          bot.post_deploy_queue
          expect(bot.instance_variable_get(:@client)).to have_received(:chat_postMessage).once
        end
      end

      describe 'post_detect_auto_deploy' do
        let(:deploy_job) do
          DeployJob.new(account: 'account', repository: 'repository', branch: 'branch')
        end

        it 'should be call bot' do
          bot.post_detect_auto_deploy(deploy_job)
          expect(bot.instance_variable_get(:@client)).to have_received(:chat_postMessage).once
        end
      end

      describe 'post_detect_slack_deploy' do
        let(:deploy_job) do
          DeployJob.new(
            account: 'account',
            repository: 'repository',
            branch: 'branch',
            cluster: 'default',
            service: 'service'
          )
        end

        it 'should be call bot' do
          bot.post_detect_slack_deploy(deploy_job)
          expect(bot.instance_variable_get(:@client)).to have_received(:chat_postMessage).once
        end
      end

      describe 'post_started_deploy' do
        let(:deploy_job) do
          DeployJob.new(
            cluster: 'cluster',
            service: 'service'
          )
        end

        it 'should be call bot' do
          bot.post_started_deploy(deploy_job, 'jid')
          expect(bot.instance_variable_get(:@client)).to have_received(:chat_postMessage).once
        end
      end

      describe 'escape_emoji' do
        it 'should be escape string' do
          expect(bot.send(:escape_emoji, ':test:')).to eq(":\u00ADtest\u00AD:")
        end
      end
    end
  end
end
