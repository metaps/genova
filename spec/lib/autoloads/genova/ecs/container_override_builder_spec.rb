require 'rails_helper'

module Genova
  module Ecs
    describe ContainerOverrideBuilder do
      describe 'build' do
        let(:base_dir) { '/repo/config' }

        it 'loads environment from files and allows inline environment to override it' do
          env_file_path = '/repo/config/app.env'
          yaml_file_path = '/repo/config/shared.yml'

          allow(File).to receive(:file?).with(env_file_path).and_return(true)
          allow(File).to receive(:file?).with(yaml_file_path).and_return(true)
          allow(File).to receive(:read).with(env_file_path).and_return("DOTENV_KEY=dotenv\nFILE_OVERRIDE=dotenv\nSHARED_KEY=dotenv\n")
          allow(File).to receive(:read).with(yaml_file_path).and_return(
            {
              'YAML_KEY' => 1,
              'FILE_OVERRIDE' => 'yaml',
              'SHARED_KEY' => 'yaml'
            }.to_yaml
          )

          container_overrides = described_class.build(
            [
              {
                name: 'app',
                command: %w[bundle exec rake],
                environment_from_files: [
                  './app.env',
                  './shared.yml'
                ],
                environment: [
                  { 'INLINE_ONLY' => 'inline' },
                  { 'SHARED_KEY' => 'inline_override' }
                ]
              }
            ],
            base_dir:
          )

          expect(container_overrides[0][:name]).to eq('app')
          expect(container_overrides[0][:command]).to eq(%w[bundle exec rake])
          expect(
            container_overrides[0][:environment].to_h { |environment| [environment[:name], environment[:value]] }
          ).to eq(
            'DOTENV_KEY' => 'dotenv',
            'FILE_OVERRIDE' => 'yaml',
            'YAML_KEY' => '1',
            'INLINE_ONLY' => 'inline',
            'SHARED_KEY' => 'inline_override'
          )
        end

        it 'strips whitespace around name/value and handles quoted values in dotenv files' do
          env_file_path = '/repo/config/app.env'

          allow(File).to receive(:file?).with(env_file_path).and_return(true)
          allow(File).to receive(:read).with(env_file_path).and_return(
            "PLAIN=value\nDOUBLE_QUOTED=\"quoted value\"\nSINGLE_QUOTED='single quoted'\nSPACED = spaced value\n"
          )

          container_overrides = described_class.build(
            [{ name: 'app', environment_from_files: ['./app.env'] }],
            base_dir:
          )

          expect(
            container_overrides[0][:environment].to_h { |e| [e[:name], e[:value]] }
          ).to eq(
            'PLAIN' => 'value',
            'DOUBLE_QUOTED' => 'quoted value',
            'SINGLE_QUOTED' => 'single quoted',
            'SPACED' => 'spaced value'
          )
        end

        it 'raises error when environment file path is invalid' do
          expect do
            described_class.build(
              [
                {
                  name: 'app',
                  environment_from_files: [nil]
                }
              ],
              base_dir:
            )
          end.to raise_error(Exceptions::ValidationError, "Invalid environment file path for container override 'app'. [nil]")
        end

        it 'raises error when environment file does not exist' do
          allow(File).to receive(:file?).with('/repo/config/missing.env').and_return(false)

          expect do
            described_class.build(
              [
                {
                  name: 'app',
                  environment_from_files: ['./missing.env']
                }
              ],
              base_dir:
            )
          end.to raise_error(Exceptions::ValidationError, 'Environment file does not exist. [/repo/config/missing.env]')
        end
      end
    end
  end
end
