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
          let(:messages) { [] }

          before do
            allow(::Github::RetrieveBranchWorker).to receive(:perform_async)
            allow(RestClient).to receive(:post) { |_url, body, _options| messages << JSON.parse(body).dig('blocks', 0, 'text', 'text') }
          end

          def payload(value)
            {
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
                    value:
                  }
                }
              ]
            }
          end

          context 'when alias is not specified' do
            it 'should show repository name' do
              Settings.add_source!(
                github: {
                  repositories: [{
                    name: 'repository'
                  }]
                }
              )
              Settings.reload!

              expect { Genova::Slack::RequestHandler.call(payload('repository')) }.to_not raise_error
              expect(messages.last).to eq("*Repository:*\nrepository\n")
            end
          end

          context 'when alias is specified' do
            it 'should show alias name' do
              Settings.add_source!(
                github: {
                  repositories: [{
                    name: 'repository',
                    base_path: './backend',
                    alias: 'repository - backend'
                  }]
                }
              )
              Settings.reload!

              expect { Genova::Slack::RequestHandler.call(payload('repository - backend')) }.to_not raise_error
              expect(messages.last).to eq("*Repository:*\nrepository - backend\n")
            end
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

          context 'when permissions are configured' do
            let(:payload) do
              {
                container: {
                  thread_ts: id
                },
                user: {
                  id: user
                },
                actions: [
                  {
                    action_id: 'submit_deploy'
                  }
                ]
              }
            end

            before do
              allow(::Slack::DeployWorker).to receive(:perform_async)
              session_store.merge({ repository: 'genova', cluster: 'production' })
            end

            def add_permissions(*policies)
              Settings.add_source!(
                slack: {
                  permissions: policies.map { |policy| { policy:, resources: ['*'], allow_users: ['allowed_user'] } }
                }
              )
              Settings.reload!
            end

            context 'when only repository policy is configured' do
              before { add_permissions('repository') }

              context 'when user is allowed' do
                let(:user) { 'allowed_user' }

                it 'should execute deploy' do
                  Genova::Slack::RequestHandler.call(payload)

                  expect(::Slack::DeployWorker).to have_received(:perform_async)
                end
              end

              context 'when user is not allowed' do
                let(:user) { 'denied_user' }

                it 'should raise error' do
                  expect { Genova::Slack::RequestHandler.call(payload) }.to raise_error(Genova::Exceptions::SlackPermissionDeniedError)
                  expect(::Slack::DeployWorker).not_to have_received(:perform_async)
                end
              end
            end

            context 'when only cluster policy is configured' do
              before { add_permissions('cluster') }

              context 'when user is allowed' do
                let(:user) { 'allowed_user' }

                it 'should execute deploy' do
                  Genova::Slack::RequestHandler.call(payload)

                  expect(::Slack::DeployWorker).to have_received(:perform_async)
                end
              end

              context 'when user is not allowed' do
                let(:user) { 'denied_user' }

                it 'should raise error' do
                  expect { Genova::Slack::RequestHandler.call(payload) }.to raise_error(Genova::Exceptions::SlackPermissionDeniedError)
                  expect(::Slack::DeployWorker).not_to have_received(:perform_async)
                end
              end
            end

            context 'when user is allowed only by cluster policy' do
              let(:user) { 'allowed_user' }

              before do
                Settings.add_source!(
                  slack: {
                    permissions: [
                      { policy: 'repository', resources: ['*'], allow_users: ['other_user'] },
                      { policy: 'cluster', resources: ['*'], allow_users: ['allowed_user'] }
                    ]
                  }
                )
                Settings.reload!
              end

              it 'should raise error' do
                expect { Genova::Slack::RequestHandler.call(payload) }.to raise_error(Genova::Exceptions::SlackPermissionDeniedError)
                expect(::Slack::DeployWorker).not_to have_received(:perform_async)
              end
            end
          end
        end

        context 'when invoke selected_workflow_deploy' do
          let(:payload) do
            {
              container: {
                thread_ts: id
              },
              user: {
                id: user
              },
              actions: [
                {
                  action_id: 'selected_workflow_deploy'
                }
              ]
            }
          end

          before do
            allow(::Slack::WorkflowDeployWorker).to receive(:perform_async)
            session_store.merge({ name: 'production_release' })

            Settings.add_source!(
              slack: {
                permissions: [{ policy: 'workflow', resources: ['production_release'], allow_users: ['allowed_user'] }]
              }
            )
            Settings.reload!
          end

          context 'when user is allowed' do
            let(:user) { 'allowed_user' }

            it 'should execute workflow deploy' do
              Genova::Slack::RequestHandler.call(payload)

              expect(::Slack::WorkflowDeployWorker).to have_received(:perform_async)
            end
          end

          context 'when user is not allowed' do
            let(:user) { 'denied_user' }

            it 'should raise error' do
              expect { Genova::Slack::RequestHandler.call(payload) }.to raise_error(Genova::Exceptions::SlackPermissionDeniedError)
              expect(::Slack::WorkflowDeployWorker).not_to have_received(:perform_async)
            end
          end
        end
      end
    end
  end
end
