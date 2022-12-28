require 'rails_helper'

module Ecs
  describe ServiceProvisioningWorker do
    describe 'perform' do
      let(:deploy_job) {
        DeployJob.create!(
          id: DeployJob.generate_id,
          mode: DeployJob.mode.find_value(:manual),
          type: DeployJob.type.find_value(:service),
          account: Settings.github.account,
          repository: 'repository',
          cluster: 'cluster',
          service: 'service'
        )
      }

      before do
        subject.perform('')
      end

      it '' do
      end
    end
  end
end
