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

        describe 'static_select_input' do
          it 'builds an input block that does not dispatch an action' do
            option = { text: { type: 'plain_text', text: 'main' }, value: 'main' }
            block = Genova::Slack::BlockKit::Helper.static_select_input(
              'workflow_branch',
              'Branch',
              [{ label: { type: 'plain_text', text: 'Default' }, options: [option] }],
              groups: true,
              initial_option: option,
              block_id: 'workflow_branch:1'
            )

            expect(block[:type]).to eq('input')
            expect(block.key?(:dispatch_action)).to eq(false)
            expect(block[:block_id]).to eq('workflow_branch:1')
            expect(block[:element][:initial_option]).to eq(option)
            expect(block[:element][:option_groups].count).to eq(1)
          end

          it 'omits initial option and block id when not specified' do
            block = Genova::Slack::BlockKit::Helper.static_select_input('action', 'Branch', [])

            expect(block.key?(:block_id)).to eq(false)
            expect(block[:element].key?(:initial_option)).to eq(false)
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
