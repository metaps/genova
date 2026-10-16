require 'rails_helper'
require 'digest'
require 'rbconfig'
require 'stringio'

module Genova
  module Command
    describe Executor do
      describe 'command' do
        it 'passes array arguments literally without a shell and closes stdin' do
          argument = 'literal $HOME; echo expanded'
          command = [RbConfig.ruby, '-e', 'exit(ARGV == ["literal $HOME; echo expanded"] && STDIN.read.empty? ? 0 : 1)', argument]

          expect(Command::Executor.call(command, ::Logger.new(nil))).to eq(0)
        end

        it 'passes sensitive input through stdin without including it in logs' do
          output = StringIO.new
          password = "private-password\nwith-special-$characters"
          command = [RbConfig.ruby, '-e', 'require "digest"; exit(Digest::SHA256.hexdigest(STDIN.read) == ARGV.fetch(0) ? 0 : 1)', Digest::SHA256.hexdigest(password)]

          exit_code = Command::Executor.call(
            command,
            ::Logger.new(output),
            filtered_command: 'stdin test',
            stdin_data: password
          )

          expect(exit_code).to eq(0)
          expect(output.string).to include('Execute command. [stdin test]')
          expect(output.string).not_to include('private-password')
        end

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
