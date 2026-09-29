require 'rails_helper'

module Genova
  module Deploy
    module Step
      describe Runner do
        describe 'call' do
          let(:chat) { double(::Slack::Web::Api::Endpoints::Chat) }
          let(:bot) { double(Slack::Interactive::Bot) }
          let(:runner) { double(Genova::Deploy::Runner) }
          let(:steps) do
            [
              {
                type:,
                resources:,
                cluster: 'cluster',
                repository: 'repository',
                branch: 'branch'
              }
            ]
          end

          before do
            DeployJob.collection.drop

            allow(chat).to receive(:ts)
            allow(bot).to receive(:show_stop_button).and_return(chat)
            allow(bot).to receive(:delete_message)
            allow(Slack::Interactive::Bot).to receive(:new).and_return(bot)

            allow(runner).to receive(:run)
            allow(Genova::Deploy::Runner).to receive(:new).and_return(runner)
          end

          context 'when update service' do
            let(:type) { 'service' }
            let(:resources) { ['resource'] }

            it 'should not error' do
              expect { Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym) }.to_not raise_error
            end

            it 'stores note in deploy job' do
              Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym, note: 'note')

              expect(DeployJob.last.note).to eq('note')
            end

            it 'truncates too long note before storing in deploy job' do
              Runner.call(
                steps,
                StdoutHook.new,
                mode: DeployJob.mode.find_value(:manual).to_sym,
                note: 'a' * (DeployJob::NOTE_MAX_LENGTH + 1)
              )

              expect(DeployJob.last.note.length).to eq(DeployJob::NOTE_MAX_LENGTH)
            end
          end

          context 'when repository has alias' do
            let(:type) { 'service' }
            let(:resources) { ['resource'] }
            let(:steps) do
              [
                {
                  type:,
                  resources:,
                  cluster: 'cluster',
                  repository: 'repository-alias',
                  branch: 'branch'
                }
              ]
            end

            before do
              allow(Genova::Config::SettingsHelper).to receive(:find_repository).with('repository-alias').and_return(
                name: 'repository',
                base_path: './base_path',
                alias: 'repository-alias'
              )
            end

            it 'resolves real repository name and stores alias in deploy job' do
              Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym)

              expect(DeployJob.last.repository).to eq('repository')
              expect(DeployJob.last.alias).to eq('repository-alias')
            end
          end

          context 'when step has alias' do
            let(:type) { 'service' }
            let(:resources) { ['resource'] }
            let(:steps) do
              [
                {
                  type:,
                  resources:,
                  cluster: 'cluster',
                  repository: 'repository',
                  alias: 'repository-alias',
                  branch: 'branch'
                }
              ]
            end

            before do
              allow(Genova::Config::SettingsHelper).to receive(:find_repository).with('repository-alias').and_return(
                name: 'repository',
                base_path: './base_path',
                alias: 'repository-alias'
              )
            end

            it 'resolves repository settings by alias' do
              Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym)

              expect(DeployJob.last.repository).to eq('repository')
              expect(DeployJob.last.alias).to eq('repository-alias')
            end

            it 'raises error before deploying any step when a later alias is unusable' do
              broken = steps + [steps[0].merge(alias: 'unknown-alias')]
              allow(Genova::Config::SettingsHelper).to receive(:find_repository).with('unknown-alias').and_return(nil)

              expect { Runner.call(broken, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym) }
                .to raise_error(Genova::Exceptions::ValidationError, /Alias is undefined/)
              expect(DeployJob.count).to eq(0)
            end

            it 'gives priority to repository option supplied by auto deploy' do
              allow(Genova::Config::SettingsHelper).to receive(:find_repository).with('other-repository').and_return(nil)

              Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:auto).to_sym, repository: 'other-repository')

              expect(DeployJob.last.repository).to eq('other-repository')
              expect(DeployJob.last.alias).to be_nil
            end
          end

          context 'when branch is overridden' do
            let(:type) { 'service' }
            let(:resources) { ['resource'] }
            let(:steps) do
              [
                {
                  type:,
                  resources:,
                  cluster: 'cluster',
                  repository: 'repository',
                  branch: 'branch'
                },
                {
                  type:,
                  resources:,
                  cluster: 'cluster',
                  repository: 'repository',
                  branch: 'branch'
                }
              ]
            end

            before do
              # `DeployJob.generate_id` is generated per second, so it is duplicated when deploying continuously in a spec.
              ids = (1..steps.size).map { |i| "#{DeployJob.generate_id}-#{i}" }
              allow(DeployJob).to receive(:generate_id).and_return(*ids)
            end

            it 'overrides branch of specified step only' do
              Runner.call(
                steps,
                StdoutHook.new,
                mode: DeployJob.mode.find_value(:manual).to_sym,
                branches: [{ step: 2, branch: 'override' }]
              )

              expect(DeployJob.asc(:id).pluck(:branch)).to eq(%w[branch override])
            end

            it 'falls back to the configured branch when the override is blank' do
              Runner.call(
                steps,
                StdoutHook.new,
                mode: DeployJob.mode.find_value(:manual).to_sym,
                branches: [{ step: 2, branch: nil }]
              )

              expect(DeployJob.asc(:id).pluck(:branch)).to eq(%w[branch branch])
            end

            it 'gives priority to branch option' do
              Runner.call(
                steps,
                StdoutHook.new,
                mode: DeployJob.mode.find_value(:manual).to_sym,
                branch: 'priority',
                branches: [{ step: 2, branch: 'override' }]
              )

              expect(DeployJob.where(branch: 'priority').count).to eq(2)
            end
          end

          context 'when update run task' do
            let(:type) { 'run_task' }
            let(:resources) { ['resource'] }

            it 'should not error' do
              expect { Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym) }.to_not raise_error
            end
          end

          context 'when update scheduled task' do
            let(:type) { 'scheduled_task' }
            let(:resources) { ['resource1:resource2'] }

            it 'should not error' do
              expect { Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym) }.to_not raise_error
            end
          end
        end
      end
    end
  end
end
