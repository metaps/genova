require 'rails_helper'

module Genova
  module Deploy
    module Workflow
      describe Runner do
        describe 'call' do
          it 'shuold be not error' do
            allow(Settings).to receive(:workflows).and_return([
                                                                name: 'name'
                                                              ])
            allow(Step::Runner).to receive(:call)
            expect { Runner.call('name', Step::StdoutHook.new, {}) }.to_not raise_error
          end
        end
      end
    end
  end
end
