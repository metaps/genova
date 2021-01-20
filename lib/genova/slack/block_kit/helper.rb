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

          def static_select(action_id, options, placeholder, params = {})
            element = {
              type: 'static_select',
              placeholder: {
                type: 'plain_text',
                text: placeholder
              },
              action_id: action_id
            }

            option_key = params[:group] ? 'option_groups' : 'options'
            element[option_key.to_sym] = options
            element
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

          def cancel_button(text, value, action_id)
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

          def escape_emoji(string)
            string.gsub(/:(\w+):/, ":\u00AD\\1\u00AD:")
          end
        end
      end
    end
  end
end
