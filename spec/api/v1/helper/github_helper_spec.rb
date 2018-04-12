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
            allow_any_instance_of(::V1::Helper::GithubHelper).to receive(:load_deploy_config).and_return(
              auto_deploy: [
                {
                  branch: 'branch',
                  cluster: 'cluster',
                  service: 'service'
                }
              ]
            )
            expect(detect_auto_deploy_service('account', 'repository', 'branch')).to eq(
              cluster: 'cluster',
              service: 'service'
            )
          end
        end
      end

      describe 'create_deploy_job' do
        it 'should be return id' do
          params = {
            account: 'account',
            repository: 'repository',
            branch: 'branch',
            cluster: 'cluster',
            service: 'service'
          }
          expect(create_deploy_job(params)).to match(/^[\d]{8}\-[\d]{6}$/)
        end
      end

      describe 'load_deploy_config' do
        it 'should be return yaml' do
          client_mock = double(Octokit::Client)
          resource_mock = double(Sawyer::Resource)

          allow(resource_mock).to receive(:attrs).and_return({content: Base64.encode64('{}')})
          allow(client_mock).to receive(:contents).and_return(resource_mock)
          allow(Octokit::Client).to receive(:new).and_return(client_mock)

          expect(load_deploy_config('account', 'repository', 'branch')).to eq({})
        end
      end
    end
  end
end
