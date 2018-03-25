require 'rails_helper'

module Genova
  module Command
    describe Executor do
      let(:executor) { Genova::Command::Executor.new }
      let(:io_mock) { double(IO) }

      describe 'command' do
        context 'when command was successful.' do
          it 'shuold be return stdout' do
            allow(io_mock).to receive(:write)
            allow(io_mock).to receive(:close)

            response = []
            response << io_mock
            response << ['stdout']
            response << []

            allow(Open3).to receive(:popen3).and_yield(*response)
            expect(executor.command('dummy')).to eq('stdout')
          end
        end

        context 'when command was failure.' do
          it 'shuold be raise error' do
            allow(io_mock).to receive(:write)
            allow(io_mock).to receive(:close)

            response = []
            response << io_mock
            response << ['stdout']
            response << ['stderr']

            allow(Open3).to receive(:popen3).and_yield(*response)
            expect { executor.command('dummy') }.to raise_error(Genova::Command::StandardError)
          end
        end

        context 'when forcibly terminated' do
          it 'shuold be raise error' do
            allow(io_mock).to receive(:write)
            allow(io_mock).to receive(:close)

            response = []
            response << io_mock
            response << []
            response << []

            allow(Open3).to receive(:popen3).and_raise(Interrupt)
            expect { executor.command('dummy') }.to raise_error(Interrupt)
          end
        end
      end
    end
  end
end
