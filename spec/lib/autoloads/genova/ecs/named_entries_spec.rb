require 'rails_helper'

module Genova
  module Ecs
    describe NamedEntries do
      describe '.normalize' do
        it 'rejects blank entry names before normalization' do
          expect do
            described_class.normalize(
              [{ name: ' ', value: '1' }],
              value_key: :value,
              entry_label: 'environment'
            )
          end.to raise_error(Exceptions::ValidationError, 'Entry name must be present.')
        end

        it 'does not include raw hash values in invalid entry messages' do
          expect do
            described_class.normalize(
              [{ name: 'PASSWORD', value: 'secret-value', unexpected: 'raw-secret' }],
              value_key: :value,
              entry_label: 'environment',
              container_identifier: 'app'
            )
          end.to raise_error(Exceptions::ValidationError) { |error|
            expect(error.message).to include("Invalid environment entry for container override 'app'.")
            expect(error.message).to include('keys:')
            expect(error.message).not_to include('secret-value')
            expect(error.message).not_to include('raw-secret')
          }
        end
      end

      describe '.parse_yaml_file' do
        it 'rejects array entries with extra keys' do
          path = '/repo/config/app.yml'
          allow(File).to receive(:read).with(path).and_return(
            [{ 'name' => 'FOO', 'value' => '1', 'BAR' => '2' }].to_yaml
          )

          expect do
            described_class.parse_yaml_file(
              path,
              file_label: 'environment',
              entry_label: 'environment',
              value_key: :value
            )
          end.to raise_error(Exceptions::ValidationError, "Invalid environment entry. [#{path}]")
        end

        it 'rejects array entries with mixed key styles' do
          path = '/repo/config/app.yml'
          allow(File).to receive(:read).with(path).and_return('yaml')
          allow(YAML).to receive(:safe_load).and_return([{ 'name' => 'FOO', value: '1' }])

          expect do
            described_class.parse_yaml_file(
              path,
              file_label: 'environment',
              entry_label: 'environment',
              value_key: :value
            )
          end.to raise_error(Exceptions::ValidationError, "Invalid environment entry. [#{path}]")
        end
      end

      describe '.parse_dotenv_file' do
        it 'keeps unquoted hashes that are not preceded by whitespace' do
          path = '/repo/config/app.env'
          allow(File).to receive(:read).with(path).and_return("PASSWORD=abc#123\nWITH_COMMENT=value # comment\n")

          entries = described_class.parse_dotenv_file(
            path,
            file_label: 'environment',
            value_key: :value
          )

          expect(entries).to eq(
            [
              { name: 'PASSWORD', value: 'abc#123' },
              { name: 'WITH_COMMENT', value: 'value' }
            ]
          )
        end
      end
    end
  end
end
