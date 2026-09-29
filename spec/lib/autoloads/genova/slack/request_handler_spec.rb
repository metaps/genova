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

        context 'when invoke workflow_branch' do
          it 'should neither touch the session nor update the message' do
            payload = {
              container: { thread_ts: id },
              user: { id: 'user' },
              actions: [
                {
                  action_id: 'workflow_branch',
                  block_id: 'workflow_branch:1',
                  selected_option: { value: 'branch' }
                }
              ]
            }

            expect { Genova::Slack::RequestHandler.call(payload) }.to_not raise_error
            expect(session_store.params.key?(:branches)).to eq(false)
            expect(RestClient).to_not have_received(:post)
          end
        end

        context 'when invoke selected_workflow_deploy' do
          before do
            allow(::Slack::WorkflowDeployWorker).to receive(:perform_async)

            Settings.add_source!(
              workflows: [
                {
                  name: 'workflow',
                  steps: [
                    { repository: 'repository', branch: 'branch1', cluster: 'cluster', type: 'service', resources: ['resource'] },
                    { repository: 'repository', branch: 'branch2', cluster: 'cluster', type: 'service', resources: ['resource'] }
                  ]
                }
              ]
            )
            Settings.reload!

            session_store.merge({ name: 'workflow' })
          end

          def payload(state_values)
            {
              container: {
                thread_ts: id
              },
              user: {
                id: 'user'
              },
              state: {
                values: state_values
              },
              actions: [
                {
                  action_id: 'selected_workflow_deploy'
                }
              ]
            }
          end

          def branch_value(branch)
            { workflow_branch: { selected_option: { value: branch } } }
          end

          it 'should store branch of each step from message state' do
            Genova::Slack::RequestHandler.call(
              payload(
                'workflow_branch:2': branch_value('branch2'),
                'workflow_branch:1': branch_value('branch1')
              )
            )

            expect(session_store.params[:branches]).to eq(
              [
                { step: 1, branch: 'branch1' },
                { step: 2, branch: 'branch2' }
              ]
            )
          end

          it 'should ignore blocks that are not branch selects' do
            Genova::Slack::RequestHandler.call(
              payload(
                'workflow_branch:1': branch_value('branch1'),
                deploy_note: { submit_deploy_note: { value: 'note' } }
              )
            )

            expect(session_store.params[:branches]).to eq([{ step: 1, branch: 'branch1' }])
            expect(session_store.params[:note]).to eq('note')
          end

          it 'should store empty branches when state is missing' do
            Genova::Slack::RequestHandler.call(payload({}))

            expect(session_store.params[:branches]).to eq([])
          end

          context 'when permissions are configured' do
            let(:permission) { instance_double(Genova::Slack::Interactive::Permission) }

            before do
              allow(Genova::Slack::Interactive::Permission).to receive(:new).and_return(permission)
              allow(permission).to receive(:allow_workflow?).and_return(true)
              allow(permission).to receive(:allow_cluster?).and_return(false)
              allow(permission).to receive(:allow_repository?).and_return(false)
            end

            it 'should authorize the workflow stored in the session' do
              Genova::Slack::RequestHandler.call(payload({}))

              expect(permission).to have_received(:allow_workflow?).with('workflow')
            end

            it 'should deny a user the workflow policy does not allow' do
              allow(permission).to receive(:allow_workflow?).and_return(false)

              expect { Genova::Slack::RequestHandler.call(payload({})) }
                .to raise_error(Genova::Exceptions::SlackPermissionDeniedError, /does not have execute permission/)
            end

            it 'should allow deploying the branches defined in settings' do
              Genova::Slack::RequestHandler.call(
                payload(
                  'workflow_branch:1': branch_value('branch1'),
                  'workflow_branch:2': branch_value('branch2')
                )
              )

              expect(::Slack::WorkflowDeployWorker).to have_received(:perform_async)
            end

            it 'should deny deploying another branch without cluster permission' do
              expect { Genova::Slack::RequestHandler.call(payload('workflow_branch:1': branch_value('hotfix'))) }
                .to raise_error(Genova::Exceptions::SlackPermissionDeniedError, /does not have permission to deploy hotfix to cluster/)
            end

            it 'should allow deploying another branch with cluster permission' do
              allow(permission).to receive(:allow_cluster?).with('cluster').and_return(true)

              Genova::Slack::RequestHandler.call(payload('workflow_branch:1': branch_value('hotfix')))

              expect(::Slack::WorkflowDeployWorker).to have_received(:perform_async)
            end

            it 'should allow deploying another branch with repository permission' do
              allow(permission).to receive(:allow_repository?).with('repository').and_return(true)

              Genova::Slack::RequestHandler.call(payload('workflow_branch:1': branch_value('hotfix')))

              expect(::Slack::WorkflowDeployWorker).to have_received(:perform_async)
            end
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
