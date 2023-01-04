require 'rails_helper'

module Genova
  module Slack
    describe RequestHandler do
      include_context :session_start

      before do
        allow(RestClient).to receive(:post)
      end

      after do
        Settings.reload_from_files(Rails.root.join('config', 'settings.yml').to_s)
      end

      describe 'call' do
        context 'when invoke cancel' do
          it 'should be execute cancel' do
            payload = {
              container: {
                thread_ts: id
              },
              user: {
                id: 'user'
              },
              actions: [
                {
                  action_id: 'cancel'
                }
              ]
            }
            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_repository' do
          it 'should be execute approve_repository' do
            Settings.add_source!(
              github: {
                repositories: [{
                  name: 'repository'
                }]
              }
            )
            Settings.reload!

            allow(::Github::RetrieveBranchWorker).to receive(:perform_async)

            payload = {
              container: {
                thread_ts: id
              },
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

            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_branch' do
          it 'should be execute approve_branch' do
            allow(::Slack::DeployClusterWorker).to receive(:perform_async)

            payload = {
              container: {
                thread_ts: id
              },
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

            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_default_branch' do
          it 'should be execute approve_default_branch' do
            allow(::Slack::DeployClusterWorker).to receive(:perform_async)

            payload = {
              container: {
                thread_ts: id
              },
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

            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_cluster' do
          it 'should be execute approve_cluster' do
            allow(::Slack::DeployTargetWorker).to receive(:perform_async)

            payload = {
              container: {
                thread_ts: id
              },
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

            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_default_cluster' do
          it 'should be execute approve_default_cluster' do
            allow(::Slack::DeployTargetWorker).to receive(:perform_async)

            payload = {
              container: {
                thread_ts: id
              },
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
            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_service' do
          it 'should be execute approve_service' do
            allow(::Slack::DeployConfirmWorker).to receive(:perform_async)

            payload = {
              container: {
                thread_ts: id
              },
              user: {
                id: 'user'
              },
              actions: [
                {
                  action_id: 'approve_service',
                  selected_option: {
                    value: 'service:api'
                  }
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_deploy_from_history' do
          let(:history) { double(Genova::Slack::Interactive::History) }

          it 'should be execute approve_deploy_from_history' do
            allow(Genova::Slack::Interactive::History).to receive(:new).and_return(history)
            allow(history).to receive(:find!).and_return({})
            allow(::Slack::DeployHistoryWorker).to receive(:perform_async)

            payload = {
              container: {
                thread_ts: id
              },
              user: {
                id: 'user'
              },
              actions: [
                {
                  action_id: 'approve_deploy_from_history'
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke approve_deploy' do
          it 'should be execute approve_deploy' do
            allow(DeployJob).to receive(:create)
            allow(::Slack::DeployWorker).to receive(:perform_async)

            payload = {
              container: {
                thread_ts: id
              },
              user: {
                id: 'user'
              },
              actions: [
                {
                  action_id: 'approve_deploy'
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end
      end
    end
  end
end
