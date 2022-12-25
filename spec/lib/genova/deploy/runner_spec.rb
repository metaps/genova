require 'rails_helper'

module Genova
  module Deploy
    describe Runner do
      let(:ecs_client) { double(Ecs::Client) }

      before do
        allow(ecs_client).to receive(:ready)
        allow(Ecs::Client).to receive(:new).and_return(ecs_client)
      end

      describe '#call' do
        context 'when deploying a service' do
          before do
            allow(ecs_client).to receive(:deploy_service)
          end

          let(:deploy_job) do
            DeployJob.create!(
              id: DeployJob.generate_id,
              mode: DeployJob.mode.find_value(:manual),
              type: DeployJob.type.find_value(:service),
              account: Settings.github.account,
              repository: 'repository',
              cluster: 'cluster',
              service: 'service'
            )
          end

          it 'shuold be not error' do
            expect { Runner.call(deploy_job, force: true) }.to_not raise_error
          end
        end
      end
    end
  end
end
