require 'rails_helper'

module Genova
  module Deploy
    describe Runner do
      let(:ecs_client_mock) { double(Ecs::Client) }
      let(:docker_client_mock) { double(Genova::Docker::Client) }
      let(:deploy_job) do
        DeployJob.create(
          id: DeployJob.generate_id,
          mode: DeployJob.mode.find_value(:manual),
          type: DeployJob.type.find_value(:service),
          account: Settings.github.account,
          repository: 'repository',
          cluster: 'cluster',
          service: 'service'
        )
      end
      let(:deploy_response) do
        deploy_response = Ecs::DeployResponse.new
        deploy_response.task_definition_arn = 'task_definition_arn'
        deploy_response.task_arns = ['task_arns']
        deploy_response
      end

      before do
        allow(ecs_client_mock).to receive(:ready)
        allow(ecs_client_mock).to receive(:deploy_service).and_return(deploy_response)

        allow(File).to receive(:file?).and_return(true)
        allow(File).to receive(:file?).with("#{ENV.fetch('HOME')}/.ssh/id_rsa").and_return(true)
        allow(Ecs::Client).to receive(:new).and_return(ecs_client_mock)

        octokit_mock = double(Octokit::Client)
        allow(octokit_mock).to receive(:create_release)
        allow(Octokit::Client).to receive(:new).and_return(octokit_mock)
      end

      describe 'run' do
        it 'shuold be not error' do
          expect { Runner.call(deploy_job) }.to_not raise_error
        end
      end
    end
  end
end
