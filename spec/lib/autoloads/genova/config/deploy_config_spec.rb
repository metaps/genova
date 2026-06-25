require 'rails_helper'

module Genova
  module Config
    describe DeployConfig do
      describe '.new' do
        let(:base_config) do
          {
            clusters: [
              {
                name: 'production',
                services: {
                  app: {
                    path: './deploy/production.yml',
                    containers: [
                      {
                        name: 'app',
                        build: {
                          context: '..'
                        }
                      }
                    ],
                    container_overrides: [
                      container_override
                    ]
                  }
                }
              }
            ]
          }
        end

        context 'when build is defined in container_overrides' do
          let(:container_override) do
            {
              name: 'app',
              build: {
                context: '..'
              }
            }
          end

          it 'accepts the config' do
            expect { described_class.new(base_config) }.not_to raise_error
          end
        end

        context 'when an unsupported key is defined in build' do
          let(:container_override) do
            {
              name: 'app',
              build: {
                contex: '..'
              }
            }
          end

          it 'raises validation error' do
            expect { described_class.new(base_config) }.to raise_error(Exceptions::ValidationError)
          end
        end

        context 'when an unsupported key is defined in container_overrides' do
          let(:container_override) do
            {
              name: 'app',
              environment_from_file: [
                './deploy/env/app.env'
              ]
            }
          end

          it 'raises validation error' do
            expect { described_class.new(base_config) }.to raise_error(Exceptions::ValidationError)
          end
        end
      end
    end
  end
end
