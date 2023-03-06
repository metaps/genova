require 'rails_helper'

module Genova
  module Deploy
    module Step
      describe Runner do
        describe 'call' do
          before do
            DeployJob.collection.drop
          end

          let(:steps) do
            [
              {
                type: 'service',
                resources: ['resource'],
                cluster: 'cluster',
                repository: 'repository',
                branch: 'branch'
              }
            ]
          end
          let(:runner) { double(Genova::Deploy::Runner) }

          it 'shuold be not error' do
            allow(runner).to receive(:run)
            allow(Genova::Deploy::Runner).to receive(:new).and_return(runner)

            expect { Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym) }.to_not raise_error
          end
        end
      end
    end
  end
end
