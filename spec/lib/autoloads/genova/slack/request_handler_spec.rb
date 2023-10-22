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
        context 'when invoke submit_cancel' do
          it 'should execute submit_cancel' do
            payload = {
              container: {
                thread_ts: id
              },
              user: {
                id: 'user'
              },
              actions: [
                {
                  action_id: 'submit_cancel'
                }
              ]
            }
            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke selected_repository' do
          it 'should execute selected_repository' do
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
                  action_id: 'selected_repository',
                  selected_option: {
                    value: 'repository'
                  }
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke selected_branch' do
          it 'should execute selected_branch' do
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
                  action_id: 'selected_branch',
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
          it 'should execute approve_default_branch' do
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
                    selected_branch: {
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
                  action_id: 'selected_branch'
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke selected_cluster' do
          it 'should execute selected_cluster' do
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
                  action_id: 'selected_cluster',
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
          it 'should execute approve_default_cluster' do
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
                    selected_cluster: {
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
                  action_id: 'selected_cluster'
                }
              ]
            }
            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke selected_service' do
          it 'should execute selected_service' do
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
                  action_id: 'selected_service',
                  selected_option: {
                    value: 'service:api'
                  }
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke submit_history' do
          let(:history) { double(Genova::Slack::Interactive::History) }

          it 'should execute submit_history' do
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
                  action_id: 'submit_history'
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
          end
        end

        context 'when invoke submit_deploy' do
          it 'should execute submit_deploy' do
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
                  action_id: 'submit_deploy'
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
