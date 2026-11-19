require 'spec_helper'
require 'thor'
require_relative '../../../lib/tasks/deploy'

RSpec.describe GenovaCli::Deploy do
  describe '#linux_user_name' do
    let(:cli) { described_class.new }
    let(:output) { "alice pts/0 2026-11-16 10:00 (192.0.2.1)\n" }
    let(:exit_status) { 0 }
    let(:env_user) { nil }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GENOVA_DEPLOY_USER').and_return(env_user)
      # Use a real subprocess so exit status handling is exercised as well.
      allow(IO).to receive(:popen).with(['who', 'am', 'i'], err: File::NULL).and_wrap_original do |original, *_args, &block|
        original.call(
          [RbConfig.ruby, '-e', 'STDOUT.write(ARGV[0]); exit(Integer(ARGV[1]))', output, exit_status.to_s],
          err: File::NULL, &block
        )
      end
    end

    context 'when the host login user is provided' do
      let(:env_user) { 'host-alice' }

      it 'prefers and caches the provided user without executing who' do
        expect(cli.linux_user_name).to eq('host-alice')
        expect(cli.linux_user_name).to eq('host-alice')
        expect(IO).not_to have_received(:popen)
        expect(ENV).to have_received(:[]).with('GENOVA_DEPLOY_USER').once
      end
    end

    context 'when the provided user has surrounding whitespace' do
      let(:env_user) { " host-alice\n" }

      it 'strips surrounding whitespace' do
        expect(cli.linux_user_name).to eq('host-alice')
        expect(IO).not_to have_received(:popen)
      end
    end

    ['', " \n"].each do |value|
      context "when GENOVA_DEPLOY_USER is #{value.inspect}" do
        let(:env_user) { value }

        it 'falls back to who am i' do
          expect(cli.linux_user_name).to eq('alice')
          expect(IO).to have_received(:popen).once
        end
      end
    end

    it 'returns only the first field and caches it for the invocation' do
      expect(cli.linux_user_name).to eq('alice')
      expect(cli.linux_user_name).to eq('alice')
      expect(IO).to have_received(:popen).once
    end

    context 'when there is no login record' do
      let(:output) { " \n" }

      it 'returns unknown' do
        expect(cli.linux_user_name).to eq('unknown')
      end
    end

    context 'when who fails' do
      let(:exit_status) { 1 }

      it 'returns unknown even if there is output' do
        expect(cli.linux_user_name).to eq('unknown')
      end
    end

    it 'returns unknown when who is not installed' do
      allow(IO).to receive(:popen).and_raise(Errno::ENOENT)

      expect(cli.linux_user_name).to eq('unknown')
    end
  end
end
