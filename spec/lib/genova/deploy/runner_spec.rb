require 'rails_helper'

module Genova
  module Deploy
    describe Runner do
      let(:ecs) { double(Ecs::Client) }

      before do
        allow(ecs).to receive(:ready)
        allow(ecs).to receive(:deploy_run_task)
        allow(ecs).to receive(:deploy_service)
        allow(ecs).to receive(:deploy_scheduled_task)
        allow(Ecs::Client).to receive(:new).and_return(ecs)
      end

      describe 'call' do
        before do
          allow(File).to receive(:file?).and_return(true)
          allow(File).to receive(:file?).with("#{ENV.fetch('HOME')}/.ssh/id_rsa").and_return(true)

          DeployJob.collection.drop
        end

        context 'when executing the run task' do
          let(:deploy_job) do
            DeployJob.create!(
              id: DeployJob.generate_id,
              mode: DeployJob.mode.find_value(:manual),
              type: DeployJob.type.find_value(:run_task),
              account: Settings.github.account,
              repository: 'repository',
              cluster: 'cluster'
            )
          end

          it 'should be \'deploy_run_task\' method is executed' do
            Runner.call(deploy_job, force: true)
            expect(ecs).to have_received(:deploy_run_task).once
          end

          it 'shuold be not error' do
            expect { Runner.call(deploy_job) }.to_not raise_error
          end
        end

        context 'when deploying a service' do
          let(:deploy_job) do
            DeployJob.create!(
              id: DeployJob.generate_id,
              mode: DeployJob.mode.find_value(:manual),
              type: DeployJob.type.find_value(:service),
              account: Settings.github.account,
              repository: 'repository',
              cluster: 'cluster'
            )
          end

          it 'should be \'deploy_service\' method is executed' do
            Runner.call(deploy_job)
            expect(ecs).to have_received(:deploy_service).once
          end

          it 'shuold be not error' do
            expect { Runner.call(deploy_job) }.to_not raise_error
          end
        end

        context 'when deploying a scheduled task' do
          let(:deploy_job) do
            DeployJob.create!(
              id: DeployJob.generate_id,
              mode: DeployJob.mode.find_value(:manual),
              type: DeployJob.type.find_value(:scheduled_task),
              account: Settings.github.account,
              repository: 'repository',
              cluster: 'cluster'
            )
          end

          it 'should be \'deploy_scheduled_task\' method is executed' do
            Runner.call(deploy_job)
            expect(ecs).to have_received(:deploy_scheduled_task).once
          end

          it 'shuold be not error' do
            expect { Runner.call(deploy_job) }.to_not raise_error
          end
        end
      end
    end
  end
end
