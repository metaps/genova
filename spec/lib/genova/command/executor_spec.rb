require 'rails_helper'

module Genova
  module Command
    describe Executor do
      describe 'command' do
        context 'when command is successfully executed' do
          it 'should be not error' do
            expect { Command::Executor.call('date') }.to_not raise_error
          end
        end

        context 'when command execution fails' do
          it 'should be not error' do
            expect { Command::Executor.call('non_existent_command') }.to raise_error(Errno::ENOENT)
          end
        end
      end
    end
  end
end
