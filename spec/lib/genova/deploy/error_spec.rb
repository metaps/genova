require 'rails_helper'

module Genova
  module Deploy
    describe Error do
      describe 'initialize' do
        it 'should be return Genova::Deploy::Error' do
          expect(Error.new).to be_a(Error)
        end
      end
    end
  end
end
