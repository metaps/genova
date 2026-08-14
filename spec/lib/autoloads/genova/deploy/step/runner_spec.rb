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
                  repository: 'reshine-profile',
                  branch: 'branch'
                }
              ]
            end

            before do
              allow(Genova::Config::SettingsHelper).to receive(:find_repository).with('reshine-profile').and_return(
                name: 'reshine',
                base_path: './profile',
                alias: 'reshine-profile'
              )
            end

            it 'resolves real repository name and stores alias in deploy job' do
              Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym)

              expect(DeployJob.last.repository).to eq('reshine')
              expect(DeployJob.last.alias).to eq('reshine-profile')
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
