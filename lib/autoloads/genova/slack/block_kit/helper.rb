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
                text:
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

          def section_short_fieldset(fields, text = nil)
            block = {
              type: 'section',
              fields:
            }
            block[:text] = { type: 'mrkdwn', text: } if text.present?
            block
          end

          def plain_text_input(action_id, label, options = {})
            block = {
              type: 'input',
              element: {
                type: 'plain_text_input',
                action_id:,
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
            block[:element][:multiline] = options[:multiline] unless options[:multiline].nil?
            block
          end

          def static_select(section, action_id, options, params = {})
            element = {
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
                action_id:
              }
            }

            option_key = (params[:groups] ? 'option_groups' : 'options').to_sym

            element[:accessory][option_key] = options
            element
          end

          # Unlike `static_select`, which renders as a section accessory, an input block does not
          # dispatch an action when it is changed. The selected value is read from the message
          # state when the surrounding message is submitted.
          def static_select_input(action_id, label, options, params = {})
            block = {
              type: 'input',
              element: {
                type: 'static_select',
                action_id:,
                placeholder: {
                  type: 'plain_text',
                  text: 'Select an item'
                }
              },
              label: {
                type: 'plain_text',
                text: label
              }
            }

            option_key = (params[:groups] ? 'option_groups' : 'options').to_sym

            block[:element][option_key] = options
            block[:element][:initial_option] = params[:initial_option] if params[:initial_option].present?
            block[:block_id] = params[:block_id] if params[:block_id].present?
            block
          end

          def radio_buttons(action_id, options)
            {
              type: 'radio_buttons',
              action_id:,
              options:
            }
          end

          def primary_button(text, value, action_id)
            {
              type: 'button',
              text: {
                type: 'plain_text',
                text:
              },
              value:,
              style: 'primary',
              action_id:
            }
          end

          def danger_button(text, value, action_id)
            {
              type: 'button',
              text: {
                type: 'plain_text',
                text:
              },
              value:,
              style: 'danger',
              action_id:
            }
          end

          def button(text, value, action_id)
            {
              type: 'button',
              text: {
                type: 'plain_text',
                text:
              },
              value:,
              action_id:
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
                  text:
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
