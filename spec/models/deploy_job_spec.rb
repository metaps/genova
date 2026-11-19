require 'rails_helper'
require 'securerandom'

RSpec.describe DeployJob, type: :model do
  describe '#executor_name' do
    it 'shows the CLI login user' do
      expect(DeployJob.new(mode: :manual, linux_user_name: 'alice').executor_name).to eq('alice')
    end

    it 'shows the Slack user for Slack deployments' do
      job = DeployJob.new(mode: :slack, slack_user_name: 'slack-alice', linux_user_name: 'alice')

      expect(job.executor_name).to eq('slack-alice')
    end

    it 'shows unknown for an existing CLI record without the field' do
      job = Mongoid::Factory.from_db(DeployJob, { '_id' => 'legacy', 'mode' => 'manual' })

      expect(job.linux_user_name).to be_nil
      expect(job.executor_name).to eq('unknown')
    end

    it 'keeps existing Slack records readable without the new field' do
      job = Mongoid::Factory.from_db(DeployJob, { '_id' => 'legacy', 'mode' => 'slack', 'slack_user_name' => 'alice' })

      expect(job.executor_name).to eq('alice')
    end
  end

  describe 'compatibility with a model without the new field' do
    it 'loads and updates a new record without removing the unknown field' do
      legacy_model = Class.new do
        include Mongoid::Document
        store_in collection: 'deploy_jobs'
        field :status, type: String
      end
      stub_const('LegacyDeployJob', legacy_model)
      id = BSON::ObjectId.new
      DeployJob.collection.insert_one('_id' => id, 'status' => 'initial', 'linux_user_name' => 'alice')

      job = LegacyDeployJob.find(id)
      expect(job.attributes['linux_user_name']).to eq('alice')
      job.update!(status: 'deploying')

      stored = DeployJob.collection.find('_id' => id).first
      expect(stored['status']).to eq('deploying')
      expect(stored['linux_user_name']).to eq('alice')
    end
  end

  describe 'note' do
    let(:base_params) do
      {
        id: SecureRandom.uuid,
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
