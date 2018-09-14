require 'rails_helper'

module Genova
  module Slack
    describe RequestHandler do
      describe 'handle_request' do
        context 'when invoke post_history' do
          it 'should be execute confirm_deploy_from_history' do
            payload_body = {
              callback_id: 'post_history',
              actions: [
                {
                  selected_options: [
                    {
                      value: 'selected_repository'
                    }
                  ]
                }
              ],
              user: {
                id: 'id'
              }
            }
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
              callback_id: 'post_repository',
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
            allow(Genova::Sidekiq::Queue).to receive(:add)
            allow(::Github::RetrieveBranchWorker).to receive(:perform_async)
            allow(Genova::Slack::RequestHandler).to receive(:watch_change_status)
            allow(Thread).to receive(:new)

            Genova::Slack::RequestHandler.handle_request(payload_body, ::Logger.new(nil))
            expect(::Github::RetrieveBranchWorker).to have_received(:perform_async).once
          end
        end

        context 'when invoke undefined route' do
          it 'should be raise error' do
            expect { Genova::Slack::RequestHandler.handle_request({ callback_id: 'undefined' }, ::Logger.new(nil)) }.to raise_error(Genova::Slack::RequestHandler::RoutingError)
          end
        end
      end
    end
  end
end
