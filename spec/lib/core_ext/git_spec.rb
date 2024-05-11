require 'rails_helper'

module Git
  describe Base do
    describe 'remote_show_origin' do
      let(:base) { Git::Base.new.instance_variable_set(:@lib, lib) }
      let(:lib) { double(::Git::Lib) }

      it 'should not error' do
        allow(lib).to receive(:remote_show_origin)
        expect { base.remote_show_origin }.to_not raise_error
      end
    end
  end

  describe Lib do
    before do
      allow(lib).to receive(:command)
      allow(lib).to receive(:command_lines)
    end

    let(:lib) { Git::Lib.new }

    describe 'branches_all' do
      before do
        allow(lib).to receive(:command_lines).and_return(['main'])
      end

      it 'should call command_lines' do
        lib.branches_all
        expect(lib).to have_received(:command_lines).with('branch', '-a', '--sort=-authordate')
      end

      it 'should return array' do
        expect(lib.branches_all).to eq([['main', false]])
      end
    end

    describe 'tags' do
      before do
        allow(lib).to receive(:command_lines).and_return(['stable'])
      end

      it 'should call command_lines' do
        lib.tags
        expect(lib).to have_received(:command_lines).with('tag', '--sort=-v:refname')
      end

      it 'should return array' do
        expect(lib.tags).to eq(['stable'])
      end
    end

    describe 'submodule_update' do
      context 'when latest_submodule is false' do
        it 'should call command' do
          lib.submodule_update(false)
          expect(lib).to have_received(:command).with('-C', nil, 'submodule', 'update')
        end
      end

      context 'when latest_submodule is true' do
        it 'should call command' do
          lib.submodule_update(true)
          expect(lib).to have_received(:command).with('-C', nil, 'submodule', 'update', '--remote')
        end
      end
    end

    describe 'remote_show_origin' do
      it 'should call command' do
        lib.remote_show_origin
        expect(lib).to have_received(:command).with('remote', 'show', 'origin')
      end
    end
  end
end
