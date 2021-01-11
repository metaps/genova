require 'rails_helper'

module Genova
  module Slack
    describe RequestHandler do
      before do
        Redis.current.flushdb
        Genova::Slack::SessionStore.new('user').start

        allow(RestClient).to receive(:post)
      end

      describe 'handle_request' do
        context 'when invoke cancel' do
          it 'should be execute cancel' do
            payload = {
              user: {
                id: 'user'
              },
              actions: [
                {
                  action_id: 'cancel'
                }
              ]
            }
            expect { Genova::Slack::RequestHandler.handle_request(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_repository' do
          it 'should be execute approve_repository' do
            allow(::Github::RetrieveBranchWorker).to receive(:perform_async)
            allow(::Github::RetrieveBranchWatchWorker).to receive(:perform_async)

            payload = {
              user: {
                id: 'user'
              },
              actions: [
                {
                  action_id: 'approve_repository',
                  selected_option: {
                    value: 'repository'
                  }
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.handle_request(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_branch' do
          it 'should be execute approve_branch' do
            allow(::Slack::DeployClusterWorker).to receive(:perform_async)

            payload = {
              user: {
                id: 'user'
              },
              actions: [
                {
                  action_id: 'approve_branch',
                  selected_opton: {
                    value: 'master'
                  }
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.handle_request(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_default_branch' do
          it 'should be execute approve_default_branch' do
            allow(::Slack::DeployClusterWorker).to receive(:perform_async)

            payload = {
              user: {
                id: 'user'
              },
              state: {
                values: {
                  block_id: {
                    approve_branch: {
                      selected_option: {
                        value: 'master'
                      }
                    }
                  }
                }
              },
              actions: [
                {
                  block_id: 'block_id',
                  action_id: 'approve_branch'
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.handle_request(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_cluster' do
          it 'should be execute approve_cluster' do
            allow(::Slack::DeployTargetWorker).to receive(:perform_async)

            payload = {
              user: {
                id: 'user'
              },
              actions: [
                {
                  action_id: 'approve_cluster',
                  selected_option: {
                    value: 'cluster'
                  }
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.handle_request(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_default_cluster' do
          it 'should be execute approve_default_cluster' do
            allow(::Slack::DeployTargetWorker).to receive(:perform_async)

            payload = {
              user: {
                id: 'user'
              },
              state: {
                values: {
                  block_id: {
                    approve_cluster: {
                      selected_option: {
                        value: 'cluster'
                      }
                    }
                  }
                }
              },
              actions: [
                {
                  block_id: 'block_id',
                  action_id: 'approve_cluster'
                }
              ]
            }
            expect { Genova::Slack::RequestHandler.handle_request(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_target' do
          it 'should be execute approve_target' do
            allow(::Slack::DeployConfirmWorker).to receive(:perform_async)

            payload = {
              user: {
                id: 'user'
              },
              actions: [
                {
                  action_id: 'approve_target',
                  selected_option: {
                    value: 'service:api'
                  }
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.handle_request(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_deploy_from_history' do
          let(:history_mock) { double(Genova::Slack::History) }

          it 'should be execute approve_deploy_from_history' do
            allow(Genova::Slack::History).to receive(:new).and_return(history_mock)
            allow(history_mock).to receive(:find!).and_return({})
            allow(::Slack::DeployHistoryWorker).to receive(:perform_async)

            payload = {
              user: {
                id: 'user'
              },
              actions: [
                {
                  action_id: 'approve_deploy_from_history'
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.handle_request(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_deploy' do
          it 'should be execute approve_deploy' do
            allow(DeployJob).to receive(:create)
            allow(::Slack::DeployWorker).to receive(:perform_async)

            payload = {
              user: {
                id: 'user'
              },
              actions: [
                {
                  action_id: 'approve_deploy'
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.handle_request(payload) }.to_not raise_error
          end
        end
      end
    end
  end
end
