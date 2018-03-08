require 'rails_helper'

module CI
  module Deploy
    describe Error do
      describe 'initialize' do
        it 'should be return CI::Deploy::Error' do
          expect(Error.new).to be_a(Error)
        end
      end
    end
  end
end
