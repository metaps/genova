require 'rails_helper'

module Genova
  describe Client do
    let(:ecs_client_mock) { double(Ecs::Client) }
    let(:docker_client_mock) { double(Genova::Docker::Client) }
    let(:deploy_job) do
      DeployJob.new(
        mode: DeployJob.mode.find_value(:manual),
        type: DeployJob.type.find_value(:service),
        account: ENV.fetch('GITHUB_ACCOUNT'),
        repository: 'repository',
        cluster: 'cluster',
        service: 'service'
      )
    end
    let(:client) { Client.new(deploy_job) }

    before do
      allow(ecs_client_mock).to receive(:ready)
      allow(ecs_client_mock).to receive(:deploy_service)

      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("#{ENV.fetch('HOME')}/.ssh/id_rsa").and_return(true)
      allow(Ecs::Client).to receive(:new).and_return(ecs_client_mock)

      octokit_mock = double(Octokit::Client)
      allow(octokit_mock).to receive(:create_release)
      allow(Octokit::Client).to receive(:new).and_return(octokit_mock)
    end

    describe 'run' do
      it 'shuold be not error' do
        expect { client.run }.to_not raise_error
      end
    end
  end
end
