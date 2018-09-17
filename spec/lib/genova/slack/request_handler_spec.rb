require 'rails_helper'

module Genova
  module Slack
    describe RequestHandler do
      describe 'handle_request' do
        context 'when invoke post_history' do
          it 'should be execute confirm_deploy_from_history' do
            payload_body = {
              callback_id: 'confirm_deploy_from_history',
              user: {
                id: 'id'
              }
            }

            allow(Genova::Slack::CallbackIdManager).to receive(:find).and_return(action: 'confirm_deploy_from_history')

            history_mock = double(Genova::Slack::History)
            allow(history_mock).to receive(:find).and_return(
              account: 'account',
              repository: 'reposotory',
              branch: 'branch',
              cluster: 'cluster',
              service: 'service'
            )
            allow(Genova::Slack::History).to receive(:new).and_return(history_mock)

            bot_mock = double(Genova::Slack::Bot)
            allow(bot_mock).to receive(:post_confirm_deploy)
            allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)
            Genova::Slack::RequestHandler.handle_request(payload_body, ::Logger.new(nil))
          end
        end

        context 'when invoke post_repository' do
          it 'should be execute choose_deploy_branch' do
            payload_body = {
              callback_id: 'choose_deploy_branch',
              actions: [
                {
                  selected_options: [
                    {
                      value: 'selected_repository'
                    }
                  ]
                }
              ],
              response_url: 'response_url'
            }
            allow(Genova::Slack::CallbackIdManager).to receive(:find).and_return(action: 'choose_deploy_branch')
            allow(Genova::Sidekiq::Queue).to receive(:add)
            allow(::Github::RetrieveBranchWorker).to receive(:perform_async)
            allow(Thread).to receive(:new)

            Genova::Slack::RequestHandler.handle_request(payload_body, ::Logger.new(nil))
            expect(::Github::RetrieveBranchWorker).to have_received(:perform_async).once
          end
        end

        context 'when invoke undefined route' do
          it 'should be raise error' do
            allow(Genova::Slack::CallbackIdManager).to receive(:find).and_return(action: 'undefined')

            expect { Genova::Slack::RequestHandler.handle_request({ callback_id: 'callback_id' }, ::Logger.new(nil)) }.to raise_error(Genova::Slack::RequestHandler::RouteError)
          end
        end
      end
    end
  end
end
