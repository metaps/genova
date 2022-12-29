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

          it 'shuold be not error' do
            allow(Deploy::Runner).to receive(:call)
            expect { Runner.call(steps, StdoutHook.new, mode: DeployJob.mode.find_value(:manual).to_sym) }.to_not raise_error
          end
        end
      end
    end
  end
end
