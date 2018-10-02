require 'rails_helper'

module Genova
  module Slack
    describe RequestHandler do
      before do
        allow(Genova::Sidekiq::Queue).to receive(:add)
      end

      describe 'handle_request' do
        context 'when invoke choose_deploy_branch' do
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
              ]
            }
            allow(Genova::Slack::CallbackIdManager).to receive(:find).and_return(action: payload_body[:callback_id])
            allow(::Github::RetrieveBranchWorker).to receive(:perform_async)
            allow(::Github::RetrieveBranchWatchWorker).to receive(:perform_async)

            expect { Genova::Slack::RequestHandler.handle_request(payload_body) }.to_not raise_error
          end
        end

        context 'when invoke choose_deploy_cluster' do
          it 'should be execute choose_deploy_cluster' do
            payload_body = {
              callback_id: 'choose_deploy_cluster',
              actions: [
                {
                  value: 'approve',
                  selected_options: [
                    {
                      value: 'selected_branch'
                    }
                  ]
                }
              ]
            }
            allow(Genova::Slack::CallbackIdManager).to receive(:find).and_return(action: payload_body[:callback_id])
            allow(::Slack::DeployClusterWorker).to receive(:perform_async)

            expect { Genova::Slack::RequestHandler.handle_request(payload_body) }.to_not raise_error
          end
        end

        context 'when invoke choose_deploy_target' do
          it 'should be execute choose_deploy_target' do
            payload_body = {
              callback_id: 'choose_deploy_target',
              actions: [
                {
                  value: 'approve',
                  selected_options: [
                    {
                      value: 'selected_target'
                    }
                  ]
                }
              ]
            }
            allow(Genova::Slack::CallbackIdManager).to receive(:find).and_return(action: payload_body[:callback_id])
            allow(::Slack::DeployTargetWorker).to receive(:perform_async)

            expect { Genova::Slack::RequestHandler.handle_request(payload_body) }.to_not raise_error
          end
        end

        context 'when invoke confirm_deploy_from_history' do
          it 'should be execute confirm_deploy_from_history' do
            payload_body = {
              callback_id: 'confirm_deploy_from_history',
              user: {
                id: 'id'
              },
              actions: [
                {
                  selected_options: [
                    {
                      value: 'selected_history'
                    }
                  ]
                }
              ]
            }

            allow(Genova::Slack::CallbackIdManager).to receive(:find).and_return(action: payload_body[:callback_id])

            history_mock = double(Genova::Slack::History)
            allow(history_mock).to receive(:find).and_return(
              account: 'account',
              repository: 'reposotory',
              branch: 'branch',
              cluster: 'cluster',
              service: 'service'
            )
            allow(Genova::Slack::History).to receive(:new).and_return(history_mock)
            allow(::Slack::DeployHistoryWorker).to receive(:perform_async)

            expect { Genova::Slack::RequestHandler.handle_request(payload_body) }.to_not raise_error
          end
        end

        context 'when invoke undefined route' do
          it 'should be raise error' do
            allow(Genova::Slack::CallbackIdManager).to receive(:find).and_return(action: 'undefined')

            expect { Genova::Slack::RequestHandler.handle_request(callback_id: 'callback_id') }.to raise_error(Genova::Slack::RequestHandler::RouteError)
          end
        end
      end
    end
  end
end
