require 'rails_helper'

module Genova
  describe Error do
    describe 'initialize' do
      it 'should be return Genova::Error' do
        expect(Error.new).to be_a(Error)
      end
    end
  end
end
