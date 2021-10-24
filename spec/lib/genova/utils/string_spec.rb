require 'rails_helper'

module Genova
  module Utils
    describe String do
      describe 'pattern_match?' do
        context 'when exact match' do
          it 'should be returned true' do
            expect(Utils::String.pattern_match?('value', 'value')).to eq(true)
          end

          it 'should be returned false' do
            expect(Utils::String.pattern_match?('not_match', 'value')).to eq(false)
          end
        end

        context 'when partial match' do
          it 'should be returned true' do
            expect(Utils::String.pattern_match?('*', 'value')).to eq(true)
            expect(Utils::String.pattern_match?('valu*', 'value')).to eq(true)
            expect(Utils::String.pattern_match?('value*', 'value')).to eq(true)
          end

          it 'should be returned false' do
            expect(Utils::String.pattern_match?('valu-*', 'value')).to eq(false)
          end
        end
      end
    end
  end
end
