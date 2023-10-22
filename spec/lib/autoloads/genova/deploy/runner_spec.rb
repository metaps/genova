require 'rails_helper'

module Genova
  module Deploy
    describe Runner do
      let(:ecs) { double(Ecs::Client) }
      let(:run_task) do
        DeployJob.create!(
          id: DeployJob.generate_id,
          mode: DeployJob.mode.find_value(:manual),
          type: DeployJob.type.find_value(:run_task),
          account: Settings.github.account,
          repository: 'repository',
          cluster: 'cluster'
        )
      end
      let(:service) do
        DeployJob.create!(
          id: DeployJob.generate_id,
          mode: DeployJob.mode.find_value(:manual),
          type: DeployJob.type.find_value(:service),
          account: Settings.github.account,
          repository: 'repository',
          cluster: 'cluster'
        )
      end
      let(:scheduled_task) do
        DeployJob.create!(
          id: DeployJob.generate_id,
          mode: DeployJob.mode.find_value(:manual),
          type: DeployJob.type.find_value(:scheduled_task),
          account: Settings.github.account,
          repository: 'repository',
          cluster: 'cluster'
        )
      end
      let(:runner) { Runner.new(service) }

      before do
        allow(ecs).to receive(:ready)
        allow(ecs).to receive(:deploy_run_task)
        allow(ecs).to receive(:deploy_service)
        allow(ecs).to receive(:deploy_scheduled_task)
        allow(Ecs::Client).to receive(:new).and_return(ecs)

        DeployJob.collection.drop
      end

      describe 'run' do
        context 'when exceptions do not occur' do
          before do
            allow(File).to receive(:file?).and_return(true)
            allow(File).to receive(:file?).with("#{ENV.fetch('HOME')}/.ssh/id_rsa").and_return(true)
          end

          context 'when executing the run task' do
            it 'should \'deploy_run_task\' method is executed' do
              Runner.new(run_task).run
              expect(ecs).to have_received(:deploy_run_task).once
            end
          end

          context 'when deploying a service' do
            it 'should \'deploy_service\' method is executed' do
              Runner.new(service).run
              expect(ecs).to have_received(:deploy_service).once
            end
          end

          context 'when deploying a scheduled task' do
            it 'should \'deploy_scheduled_task\' method is executed' do
              Runner.new(scheduled_task).run
              expect(ecs).to have_received(:deploy_scheduled_task).once
            end
          end
        end

        context 'when interrupt occur' do
          it 'should return exit 1' do
            allow(ecs).to receive(:deploy_service).and_raise(Interrupt)
            allow($stdout).to receive(:write)

            expect { runner.run }.to raise_error(SystemExit)
            expect(service.status).to eq(:cancel)
          end
        end

        context 'when runtime exception do occur' do
          it 'should return exit 1' do
            allow(ecs).to receive(:deploy_service).and_raise(RuntimeError)
            allow($stdout).to receive(:write)

            expect { runner.run }.to raise_error(SystemExit)
            expect(service.status).to eq(:failure)
          end
        end
      end
    end
  end
end
