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

            it 'shuold be not error' do
              expect { Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym) }.to_not raise_error
            end
          end

          context 'when update run task' do
            let(:type) { 'run_task' }
            let(:resources) { ['resource'] }

            it 'shuold be not error' do
              expect { Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym) }.to_not raise_error
            end
          end

          context 'when update scheduled task' do
            let(:type) { 'scheduled_task' }
            let(:resources) { ['resource1:resource2'] }

            it 'shuold be not error' do
              expect { Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym) }.to_not raise_error
            end
          end
        end
      end
    end
  end
end
