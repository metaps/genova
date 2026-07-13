require 'rails_helper'

RSpec.describe DeployJob, type: :model do
  describe 'note' do
    let(:base_params) do
      {
        id: DeployJob.generate_id,
        mode: DeployJob.mode.find_value(:manual),
        type: DeployJob.type.find_value(:service),
        account: Settings.github.account,
        repository: 'repository',
        cluster: 'cluster'
      }
    end

    it 'truncates note before validation' do
      deploy_job = DeployJob.create!(base_params.merge(note: 'a' * (DeployJob::NOTE_MAX_LENGTH + 1)))

      expect(deploy_job.note.length).to eq(DeployJob::NOTE_MAX_LENGTH)
    end

    it 'keeps note within max length valid' do
      deploy_job = DeployJob.new(base_params.merge(note: 'a' * DeployJob::NOTE_MAX_LENGTH))

      expect(deploy_job).to be_valid
    end
  end
end
