require 'rails_helper'

module Genova
  module Slack
    module BlockKit
      describe Helper do
        describe 'plain_text_input' do
          it 'supports multiline input' do
            block = Genova::Slack::BlockKit::Helper.plain_text_input('action', 'Label', placeholder: 'Input text', multiline: true)

            expect(block[:element][:multiline]).to eq(true)
          end
        end

        describe 'escape_emoji' do
          it 'should escape string' do
            expect(Genova::Slack::BlockKit::Helper.send(:escape_emoji, ':test:')).to eq(":\u00ADtest\u00AD:")
          end
        end
      end
    end
  end
end
