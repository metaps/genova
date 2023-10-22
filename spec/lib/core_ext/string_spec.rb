require 'rails_helper'

describe String do
  describe 'pattern_match?' do
    context 'when exact match' do
      it 'should returned true' do
        expect('value'.pattern_match?('value')).to eq(true)
      end

      it 'should returned false' do
        expect('not_match'.pattern_match?('value')).to eq(false)
      end
    end

    context 'when partial match' do
      it 'should returned true' do
        expect('*'.pattern_match?('value')).to eq(true)
        expect('valu*'.pattern_match?('value')).to eq(true)
        expect('value*'.pattern_match?('value')).to eq(true)
      end

      it 'should returned false' do
        expect('valu-*'.pattern_match?('value')).to eq(false)
      end
    end
  end
end
