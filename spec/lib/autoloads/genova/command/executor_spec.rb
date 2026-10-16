require 'rails_helper'
require 'digest'
require 'rbconfig'
require 'stringio'
require 'timeout'

module Genova
  module Command
    describe Executor do
      describe 'command' do
        [0, 7].each do |exit_status|
          it "collects output and exit status #{exit_status} when the child exits without reading stdin" do
            output = StringIO.new
            command = [RbConfig.ruby, '-e', 'puts "early-stdout"; warn "early-stderr"; exit(Integer(ARGV.fetch(0)))', exit_status.to_s]

            status = Timeout.timeout(10) do
              Command::Executor.call(command, ::Logger.new(output), stdin_data: 'x' * (1024 * 1024))
            end

            expect(status).to eq(exit_status)
            expect(output.string).to include('early-stdout', 'early-stderr')
          end
        end

        it 'keeps stdin and loggers separate when commands run concurrently' do
          login_output = StringIO.new
          other_output = StringIO.new
          password = 'concurrent-password'
          login_command = [RbConfig.ruby, '-e', 'require "digest"; puts "login-output"; exit(Digest::SHA256.hexdigest(STDIN.read) == ARGV.fetch(0) ? 0 : 1)', Digest::SHA256.hexdigest(password)]
          ready = Queue.new
          resume = Queue.new

          allow(Open3).to receive(:popen3).and_wrap_original do |original, *args, &block|
            original.call(*args) do |*streams|
              if args == login_command
                ready << true
                resume.pop
              end
              block.call(*streams)
            end
          end

          login_thread = Thread.new do
            Command::Executor.call(login_command, ::Logger.new(login_output), filtered_command: 'login', stdin_data: password)
          end

          Timeout.timeout(10) do
            ready.pop
            other_status = Command::Executor.call([RbConfig.ruby, '-e', 'puts "other-output"'], ::Logger.new(other_output))
            resume << true

            expect(other_status).to eq(0)
            expect(login_thread.value).to eq(0)
          end

          expect(login_output.string).to include('login-output')
          expect(login_output.string).not_to include('other-output', password)
          expect(other_output.string).to include('other-output')
          expect(other_output.string).not_to include('login-output', password)
        ensure
          resume << true if resume
          login_thread.kill.join if login_thread && !login_thread.join(5)
        end

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
