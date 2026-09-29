require 'rails_helper'

module Genova
  module Config
    describe SettingsHelper do
      before do
        Settings.add_source!(
          github: {
            repositories: [
              { name: 'repository' },
              { name: 'monorepo', base_path: './api', alias: 'monorepo (api)' }
            ]
          }
        )
        Settings.reload!
      end

      after do
        Settings.reload_from_files(Rails.root.join('config', 'settings.yml').to_s)
      end

      describe 'find_step_repository' do
        it 'should resolve step by alias' do
          result = SettingsHelper.find_step_repository(repository: 'monorepo', alias: 'monorepo (api)')

          expect(result[:base_path]).to eq('./api')
        end

        it 'should resolve step without alias' do
          result = SettingsHelper.find_step_repository(repository: 'repository')

          expect(result[:name]).to eq('repository')
        end

        it 'should raise error when alias does not exist' do
          expect { SettingsHelper.find_step_repository(repository: 'monorepo', alias: 'unknown') }
            .to raise_error(Genova::Exceptions::ValidationError, /Alias is undefined/)
        end

        it 'should raise error when alias belongs to another repository' do
          expect { SettingsHelper.find_step_repository(repository: 'repository', alias: 'monorepo (api)') }
            .to raise_error(Genova::Exceptions::ValidationError, /Alias belongs to monorepo/)
        end
      end
    end
  end
end
