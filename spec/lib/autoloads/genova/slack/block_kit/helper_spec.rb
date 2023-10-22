require 'rails_helper'

module Genova
  module Slack
    module BlockKit
      describe Helper do
        describe 'escape_emoji' do
          it 'should escape string' do
            expect(Genova::Slack::BlockKit::Helper.send(:escape_emoji, ':test:')).to eq(":\u00ADtest\u00AD:")
          end
        end
      end
    end
  end
end
