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

    context 'when note is required' do
      before do
        allow(Settings.deploy).to receive(:note_required).and_return(true)
      end

      it 'is invalid when note is blank' do
        deploy_job = DeployJob.new(base_params)

        expect(deploy_job).not_to be_valid
        expect(deploy_job.errors[:note]).to include("can't be blank")
      end

      it 'is valid when note is present' do
        deploy_job = DeployJob.new(base_params.merge(note: 'note'))

        expect(deploy_job).to be_valid
      end

      it 'does not require a note for automatic deployments' do
        deploy_job = DeployJob.new(base_params.merge(mode: DeployJob.mode.find_value(:auto)))

        expect(deploy_job).to be_valid
      end

      %i[manual slack].each do |mode|
        it "allows status updates for an existing #{mode} deployment without a note" do
          allow(Settings.deploy).to receive(:note_required).and_return(false)
          deploy_job = DeployJob.create!(base_params.merge(mode: DeployJob.mode.find_value(mode), status: :initial))
          allow(Settings.deploy).to receive(:note_required).and_return(true)

          deploy_job.update!(status: :deploying)

          expect(deploy_job.reload.status).to eq(DeployJob.status.find_value(:deploying))
          expect(deploy_job.note).to be_nil
        end
      end
    end
  end
end
