require 'rails_helper'
require 'securerandom'

RSpec.describe 'Build-only deployment' do
  %i[service run_task scheduled_task].each do |type|
    context "for #{type}" do
      let(:job) do
        DeployJob.create!(
          id: SecureRandom.uuid, mode: :manual, type: type, status: :initial,
          account: Settings.github.account, repository: 'repository', branch: 'develop',
          cluster: 'cluster', service: 'api', run_task: 'migration',
          scheduled_task_rule: 'nightly', scheduled_task_target: 'target', build_only: true
        )
      end
      let(:config) do
        { path: 'task.yml', containers: [{ name: 'web', build: '.' }],
          task_role: 'unused-role', task_execution_role: 'unused-execution-role' }
      end
      let(:deploy_config) { double('deploy_config') }
      let(:code_manager) { double('code_manager', update: 'commit-id', update_submodule: nil, deploy_config: deploy_config, base_path: '/repo', task_definition_config_path: '/repo/config/task.yml') }
      let(:docker_client) { double('docker_client', build_image: 1.5) }
      let(:ecr_client) { double('ecr_client', authenticate: nil, push_image: nil) }
      let(:task_definition) do
        Aws::ECS::Types::TaskDefinition.new(
          task_definition_arn: 'arn:aws:ecs:ap-northeast-1:123456789012:task-definition/api:42',
          container_definitions: [Aws::ECS::Types::ContainerDefinition.new(name: 'web', image: '123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/app/api:latest')]
        )
      end
      let(:task_client) { double('task_client', register: task_definition) }
      let(:runner) { Genova::Deploy::Runner.new(job) }

      before do
        DeployJob.collection.drop
        Genova::RedisPool.get.flushdb
        allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager)
        allow(deploy_config).to receive(:find_service).and_return(config)
        allow(deploy_config).to receive(:find_run_task).and_return(config)
        allow(deploy_config).to receive(:find_scheduled_task_target).and_return(config)
        allow(deploy_config).to receive(:find_scheduled_task_rule).and_return(latest_submodule: true)
        allow(Genova::Docker::Registry).to receive(:new).and_return(double(login: nil))
        allow(Genova::Docker::Client).to receive(:new).and_return(docker_client)
        allow(Genova::Ecr::Client).to receive(:new).and_return(ecr_client)
        allow(Genova::Ecs::Task::Client).to receive(:new).and_return(task_client)

        expect(Genova::Ecs::Deployer::Service::Client).not_to receive(:new)
        expect(Genova::Ecs::Deployer::RunTask::Client).not_to receive(:new)
        expect(Genova::Ecs::Deployer::ScheduledTask::Client).not_to receive(:new)
        expect(Genova::Ecs::Deployer::ScheduledTask::Target).not_to receive(:build)
        expect(Aws::IAM::Role).not_to receive(:new)
        expect(job).not_to receive(:finished)
      end

      it 'registers a task definition and pushes the image, then completes without deploying' do
        expect(task_client).to receive(:register).with('/repo/config/task.yml', nil, tag: job.label).ordered.and_return(task_definition)
        expect(docker_client).to receive(:build_image).with(config[:containers][0], 'app/api').ordered.and_return(1.5)
        expect(ecr_client).to receive(:push_image).with(job.label, 'app/api').ordered
        expect(job).not_to receive(:update_status_deploying)

        runner.run

        expect(job.reload.status).to eq('success')
        expect(job.task_definition_arn).to eq(task_definition.task_definition_arn)
        expect(job.docker_build_time).to eq(1.5)
        expect(job.execution_time).to be >= 0
        expect(job.task_arns).to be_nil
        expect(job.deployment_tag).to be_nil
        expect(Genova::Deploy::Transaction.new(job.repository).running?).to be_falsey
      end

      it 'fails and releases the repository lock if the build fails' do
        allow(docker_client).to receive(:build_image).and_raise(Genova::Exceptions::ImageBuildError, 'build failed')
        expect(ecr_client).not_to receive(:push_image)

        expect { runner.run }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }

        expect(job.reload.status).to eq('failure')
        expect(job.task_definition_arn).to eq(task_definition.task_definition_arn)
        expect(Genova::Deploy::Transaction.new(job.repository).running?).to be_falsey
      end

      it 'fails and releases the repository lock if the push fails' do
        allow(ecr_client).to receive(:push_image).and_raise(StandardError, 'push failed')

        expect { runner.run }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }

        expect(job.reload.status).to eq('failure')
        expect(Genova::Deploy::Transaction.new(job.repository).running?).to be_falsey
      end

      it 'honors cancellation before marking the build successful' do
        allow(ecr_client).to receive(:push_image) { DeployJob.find(job.id).update_status_reserved_cancel }

        expect { runner.run }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }

        expect(job.reload.status).to eq('cancel')
        expect(Genova::Deploy::Transaction.new(job.repository).running?).to be_falsey
      end
    end
  end
end
