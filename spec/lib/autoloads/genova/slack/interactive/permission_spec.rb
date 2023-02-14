require 'rails_helper'

module Genova
  module Slack
    module Interactive
      describe Permission do
        let(:permission) { Genova::Slack::Interactive::Permission.new('user') }

        after do
          Settings.reload_from_files(Rails.root.join('config', 'settings.yml').to_s)
        end

        describe 'allow_repository?' do
          context 'when user has repository access' do
            it 'should be allow access' do
              Settings.add_source!(
                slack: {
                  permissions: [{
                    policy: 'repository',
                    resources: ['genova-api'],
                    allow_users: ['user']
                  }]
                }
              )
              Settings.reload!

              expect(permission.allow_repository?('genova-api')).to eq(true)
            end
          end

          context 'when the user does not have repository access' do
            it 'should be not allow access' do
              Settings.add_source!(
                slack: {
                  permissions: [{
                    policy: 'repository',
                    resources: ['genova-api'],
                    allow_users: ['user']
                  }]
                }
              )
              Settings.reload!

              expect(permission.allow_repository?('genova-frontend')).to eq(false)
            end
          end
        end
      end
    end
  end
end
