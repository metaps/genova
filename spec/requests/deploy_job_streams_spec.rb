require 'rails_helper'

RSpec.describe 'DeployJobStreams', type: :request do
  before { DeployJob.collection.drop }

  describe 'GET /deploy_jobs/:id/stream' do
    it 'streams existing logs and a finished status for a completed job as SSE' do
      deploy_job = DeployJob.create!(
        id: DeployJob.generate_id,
        mode: DeployJob.mode.find_value(:manual),
        type: DeployJob.type.find_value(:service),
        account: 'account',
        repository: 'repository',
        cluster: 'cluster',
        status: 'success',
        logs: ['line 1', 'line 2']
      )

      get "/deploy_jobs/#{deploy_job.id}/stream"

      expect(response.media_type).to eq('text/event-stream')
      expect(response.headers['X-Accel-Buffering']).to eq('no')
      expect(response.body).to include('"type":"log"', 'line 1', 'line 2')
      expect(response.body).to include('"type":"status"', '"status":"success"', '"finished":true')
    end

    it 'skips log lines already rendered when an offset is given' do
      deploy_job = DeployJob.create!(
        id: DeployJob.generate_id,
        mode: DeployJob.mode.find_value(:manual),
        type: DeployJob.type.find_value(:service),
        account: 'account',
        repository: 'repository',
        cluster: 'cluster',
        status: 'success',
        logs: ['line 1', 'line 2']
      )

      get "/deploy_jobs/#{deploy_job.id}/stream", params: { offset: 1 }

      expect(response.body).not_to include('line 1')
      expect(response.body).to include('line 2')
    end

    it 'returns 404 for an unknown job' do
      get '/deploy_jobs/unknown/stream'

      expect(response).to have_http_status(:not_found)
    end
  end
end
