require 'rails_helper'

module Genova
  module Slack
    describe BlockKitHelper do
      describe 'escape_emoji' do
        it 'should be escape string' do
          expect(Genova::Slack::BlockKitHelper.send(:escape_emoji, ':test:')).to eq(":\u00ADtest\u00AD:")
        end
      end
    end
  end
end
