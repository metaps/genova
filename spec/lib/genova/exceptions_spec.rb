require 'rails_helper'

module Genova
  describe Exceptions do
    describe 'initialize' do
      it 'should be return Exceptions::Error' do
        expect(Exceptions::Error.new).to be_a(Exceptions::Error)
      end
    end
  end
end
