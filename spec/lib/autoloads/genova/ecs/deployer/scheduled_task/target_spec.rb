require 'rails_helper'

module Genova
  module Ecs
    module Deployer
      module ScheduledTask
        describe Target do
          describe 'override_container' do
            it 'ignores build in container_overrides' do
              override = described_class.send(
                :override_container,
                {
                  name: 'web',
                  build: {
                    context: '..'
                  },
                  command: %w[bundle exec rake],
                  environment: [
                    { 'RAILS_ENV' => 'production' }
                  ]
                }
              )

              expect(override).to eq(
                {
                  name: 'web',
                  command: %w[bundle exec rake],
                  environment: [
                    { name: 'RAILS_ENV', value: 'production' }
                  ]
                }
              )
            end
          end
        end
      end
    end
  end
end
