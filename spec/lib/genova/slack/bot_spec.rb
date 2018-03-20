require 'rails_helper'

module Genova
  module Slack
    describe Bot do
      let(:bot) { Genova::Slack::Bot.new }
      let(:slack_web_client_mock) { double('::Slack::Web::Client') }

      before do
        allow(::Slack::Web::Client).to receive(:new).and_return(slack_web_client_mock)
        allow(slack_web_client_mock).to receive(:chat_postMessage)
      end

      describe 'initialize' do
        it 'should be return instance' do
          expect(bot).to be_a(Genova::Slack::Bot)
        end
      end

      describe 'post_choose_deploy_service' do
        it 'should be call bot' do
          repository_manager_mock = double(Genova::Git::LocalRepositoryManager)
          allow(repository_manager_mock).to receive(:open_deploy_config).and_return({ clusters: [] })
          allow(Genova::Git::LocalRepositoryManager).to receive(:new).and_return(repository_manager_mock)

          bot.post_choose_deploy_service(
            account: 'account',
            repository: 'repository',
            branch: 'branch'
          )
          expect(bot.instance_variable_get(:@client)).to have_received(:chat_postMessage).once
        end
      end

      describe 'post_confirm_deploy' do
        it 'should be call bot' do
          allow(bot).to receive(:compare_commit_ids).and_return(deployed_commit_id: '', current_commit_id: '')

          bot.post_confirm_deploy(
            account: 'account',
            repository: 'repository',
            branch: 'branch',
            cluster: 'cluster',
            service: 'service'
          )
          expect(bot.instance_variable_get(:@client)).to have_received(:chat_postMessage).once
        end
      end

      describe 'post_deploy_queue' do
        it 'should be call bot' do
          bot.post_deploy_queue
          expect(bot.instance_variable_get(:@client)).to have_received(:chat_postMessage).once
        end
      end

      describe 'post_detect_auto_deploy' do
        it 'should be call bot' do
          bot.post_detect_auto_deploy(
            account: 'account',
            repository: 'registry',
            branch: 'branch'
          )
          expect(bot.instance_variable_get(:@client)).to have_received(:chat_postMessage).once
        end
      end

      describe 'post_detect_slack_deploy' do
        it 'should be call bot' do
          bot.post_detect_slack_deploy(
            account: 'account',
            repository: 'repository',
            branch: 'branch',
            cluster: 'default',
            service: 'service'
          )
          expect(bot.instance_variable_get(:@client)).to have_received(:chat_postMessage).once
        end
      end

      describe 'post_started_deploy' do
        it 'should be call bot' do
          bot.post_started_deploy(
            cluster: 'cluster',
            service: 'service',
            jid: 'jid',
            deploy_job_id: 'deploy_job_id'
          )
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
