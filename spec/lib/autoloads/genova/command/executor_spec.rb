require 'rails_helper'

module Genova
  module Command
    describe Executor do
      describe 'command' do
        context 'when command is successfully executed' do
          it 'should not error' do
            expect { Command::Executor.call('date', ::Logger.new($stdout)) }.to_not raise_error
          end
        end

        context 'when command execution fails' do
          it 'should not error' do
            expect { Command::Executor.call('non_existent_command', ::Logger.new($stdout)) }.to raise_error(Errno::ENOENT)
          end
        end
      end
    end
  end
end
