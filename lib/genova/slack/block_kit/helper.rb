module Genova
  module Slack
    module BlockKit
      class Helper
        class << self
          def header(header)
            {
              type: 'header',
              text: {
                type: 'plain_text',
                text: header
              }
            }
          end

          def section(text)
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: text
              }
            }
          end

          def section_field(header, text)
            "*#{header}:*\n#{text}\n"
          end

          def section_fieldset(fields)
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: fields.join
              }
            }
          end

          def section_short_field(header, text)
            {
              type: 'mrkdwn',
              text: "*#{header}:*\n#{text}\n"
            }
          end

          def section_short_fieldset(fields)
            {
              type: 'section',
              fields: fields
            }
          end

          def plain_text_input(action_id, label, options = {})
            block = {
              type: 'input',
              element: {
                type: 'plain_text_input',
                action_id: action_id,
                placeholder: {
                  type: 'plain_text',
                  text: options[:placeholder]
                }
              },
              label: {
                type: 'plain_text',
                text: label
              }
            }
            block[:block_id] = options[:block_id] if options[:block_id].present?
            block
          end

          def static_select(section, action_id, options)
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: section
              },
              accessory: {
                type: 'static_select',
                placeholder: {
                  type: 'plain_text',
                  text: 'Select an item'
                },
                action_id: action_id,
                options: options
              }
            }
          end

          def radio_buttons(action_id, options)
            {
              type: 'radio_buttons',
              action_id: action_id,
              options: options
            }
          end

          def primary_button(text, value, action_id)
            {
              type: 'button',
              text: {
                type: 'plain_text',
                text: text
              },
              value: value,
              style: 'primary',
              action_id: action_id
            }
          end

          def button(text, value, action_id)
            {
              type: 'button',
              text: {
                type: 'plain_text',
                text: text
              },
              value: value,
              action_id: action_id
            }
          end

          def actions(actions)
            {
              type: 'actions',
              elements: actions
            }
          end

          def divider
            {
              type: 'divider'
            }
          end

          def context_markdown(text)
            {
              type: 'context',
              elements: [
                {
                  type: 'mrkdwn',
                  text: text
                }
              ]
            }
          end

          def escape_emoji(string)
            string.gsub(/:(\w+):/, ":\u00AD\\1\u00AD:")
          end
        end
      end
    end
  end
end
