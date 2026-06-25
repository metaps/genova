require 'rails_helper'

module Genova
  module Ecs
    describe ContainerOverrideBuilder do
      describe 'build' do
        let(:base_dir) { '/repo/config' }
        let(:logger) { instance_double(Logger, warn: nil) }

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

        it 'loads secrets from files and allows inline secrets to override it' do
          env_file_path = '/repo/config/secrets.env'
          yaml_file_path = '/repo/config/shared-secrets.yml'

          allow(File).to receive(:file?).with(env_file_path).and_return(true)
          allow(File).to receive(:file?).with(yaml_file_path).and_return(true)
          allow(File).to receive(:read).with(env_file_path).and_return("DOTENV_SECRET=/dotenv\nFILE_OVERRIDE=/dotenv-override\nSHARED_SECRET=/dotenv-shared\n")
          allow(File).to receive(:read).with(yaml_file_path).and_return(
            {
              'YAML_SECRET' => '/yaml',
              'FILE_OVERRIDE' => '/yaml-override',
              'SHARED_SECRET' => '/yaml-shared'
            }.to_yaml
          )

          container_overrides = described_class.build(
            [
              {
                name: 'app',
                secrets_from_files: [
                  './secrets.env',
                  './shared-secrets.yml'
                ],
                secrets: [
                  { 'INLINE_SECRET' => '/inline' },
                  { 'SHARED_SECRET' => '/inline-override' }
                ]
              }
            ],
            base_dir:
          )

          expect(
            container_overrides[0][:secrets].to_h { |secret| [secret[:name], secret[:value_from]] }
          ).to eq(
            'DOTENV_SECRET' => '/dotenv',
            'FILE_OVERRIDE' => '/yaml-override',
            'YAML_SECRET' => '/yaml',
            'INLINE_SECRET' => '/inline',
            'SHARED_SECRET' => '/inline-override'
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

        it 'strips whitespace around name/value_from and handles quoted values in secrets dotenv files' do
          env_file_path = '/repo/config/secrets.env'

          allow(File).to receive(:file?).with(env_file_path).and_return(true)
          allow(File).to receive(:read).with(env_file_path).and_return(
            "PLAIN=/path/plain\nDOUBLE_QUOTED=\"/path/quoted value\"\nSINGLE_QUOTED='/path/single quoted'\nSPACED = /path/spaced value\n"
          )

          container_overrides = described_class.build(
            [{ name: 'app', secrets_from_files: ['./secrets.env'] }],
            base_dir:
          )

          expect(
            container_overrides[0][:secrets].to_h { |secret| [secret[:name], secret[:value_from]] }
          ).to eq(
            'PLAIN' => '/path/plain',
            'DOUBLE_QUOTED' => '/path/quoted value',
            'SINGLE_QUOTED' => '/path/single quoted',
            'SPACED' => '/path/spaced value'
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

        it 'raises error when secrets file path is invalid' do
          expect do
            described_class.build(
              [
                {
                  name: 'app',
                  secrets_from_files: [nil]
                }
              ],
              base_dir:
            )
          end.to raise_error(Exceptions::ValidationError, "Invalid secrets file path for container override 'app'. [nil]")
        end

        it 'raises error when secrets file does not exist' do
          allow(File).to receive(:file?).with('/repo/config/missing-secrets.env').and_return(false)

          expect do
            described_class.build(
              [
                {
                  name: 'app',
                  secrets_from_files: ['./missing-secrets.env']
                }
              ],
              base_dir:
            )
          end.to raise_error(Exceptions::ValidationError, 'Secrets file does not exist. [/repo/config/missing-secrets.env]')
        end

        it 'warns and ignores build key' do
          expect(logger).to receive(:warn).with(
            "Ignore 'build' key in container override 'app'."
          )

          container_overrides = described_class.build(
            [
              {
                name: 'app',
                command: %w[bundle exec rake],
                build: {
                  context: '..'
                }
              }
            ],
            base_dir:,
            logger:
          )

          expect(container_overrides).to eq(
            [
              {
                name: 'app',
                command: %w[bundle exec rake]
              }
            ]
          )
        end

        it 'raises error when unsupported keys are defined' do
          expect do
            described_class.build(
              [
                {
                  name: 'app',
                  unsupported: 'value'
                }
              ],
              base_dir:,
              logger:
            )
          end.to raise_error(
            Exceptions::ValidationError,
            "Unsupported keys in container override 'app'. [unsupported]"
          )
        end
      end
    end
  end
end
