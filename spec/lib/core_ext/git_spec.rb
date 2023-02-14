require 'rails_helper'

module Git
  describe Base do
    describe 'remote_show_origin' do
      let(:base) { Git::Base.new.instance_variable_set(:@lib, lib) }
      let(:lib) { double(::Git::Lib) }

      it 'shuold be not error' do
        allow(lib).to receive(:remote_show_origin)
        expect { base.remote_show_origin }.to_not raise_error
      end
    end
  end

  describe Lib do
    let(:lib) { Git::Lib.new }

    describe 'branches_all' do
      it 'shuold be return array' do
        allow(lib).to receive(:command_lines).and_return(['main'])
        expect(lib.branches_all.size).to eq(1)
      end
    end

    describe 'tags' do
      it 'shuold be return array' do
        allow(lib).to receive(:command_lines).and_return(['stable'])
        expect(lib.tags.size).to eq(1)
      end
    end

    describe 'remote_show_origin' do
      it 'shuold be return command result' do
        allow(lib).to receive(:command).and_return('remote show origin')
        expect(lib.remote_show_origin).to eq('remote show origin')
      end
    end
  end
end
