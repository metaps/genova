require 'rails_helper'

module V1
  module Helper
    describe GithubHelper do
      include ::V1::Helper::GithubHelper

      describe 'detect_auto_deploy_service' do
        context 'when auto_deploy section does not exist' do
          it 'should be return nil' do
            allow_any_instance_of(::V1::Helper::GithubHelper).to receive(:load_deploy_config).and_return({})
            expect(detect_auto_deploy_service('account', 'repository', 'branch')).to eq(nil)
          end
        end

        context 'when auto_deploy section is exist' do
          it 'should be return hash' do
            allow_any_instance_of(::V1::Helper::GithubHelper).to receive(:load_deploy_config).and_return({
              auto_deploy: [
                {
                  branch: 'branch',
                  cluster: 'cluster',
                  service: 'service'
                }
              ]
            })
            expect(detect_auto_deploy_service('account', 'repository', 'branch')).to eq({
              cluster: 'cluster',
              service: 'service'
            })
          end
        end
      end
    end
  end
end
