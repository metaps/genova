require 'rails_helper'

RSpec.describe DeployJobsController, type: :controller do
  let(:deploy_job) do
    DeployJob.create!(
      id: DeployJob.generate_id,
      mode: DeployJob.mode.find_value(:manual),
      type: DeployJob.type.find_value(:service),
      account: Settings.github.account,
      repository: 'repository',
      cluster: 'cluster',
      service: 'service',
      task_definition_arn: 'new_task_definition_arn'
    )
  end

  describe 'GET #index' do
    it 'should return success' do
      get :index
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #show' do
    before do
      DeployJob.collection.drop
    end

    context 'when DeployJob exist.' do
      it 'should return 200' do
        expect(get(:show, params: { id: deploy_job.id })).to have_http_status(:ok)
      end

      context 'when note contains line breaks' do
        render_views

        let(:deploy_job) do
          DeployJob.create!(
            id: DeployJob.generate_id,
            mode: DeployJob.mode.find_value(:manual),
            type: DeployJob.type.find_value(:service),
            account: Settings.github.account,
            repository: 'repository',
            cluster: 'cluster',
            service: 'service',
            task_definition_arn: 'new_task_definition_arn',
            note: "<b>first line</b>\nsecond line"
          )
        end

        it 'renders escaped note with line breaks' do
          get :show, params: { id: deploy_job.id }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include('&lt;b&gt;first line&lt;/b&gt;<br')
          expect(response.body).to include('second line')
          expect(response.body).not_to include('<b>first line</b>')
        end
      end
    end

    context 'when DeployJob not exist.' do
      it 'should return 404' do
        expect(get(:show, params: { id: 'dummy' })).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET #download' do
    context 'when DeployJob exist.' do
      it 'should return 200' do
        expect(get(:download, params: { id: deploy_job.id })).to have_http_status(:ok)
      end

      it 'should redirect' do
        expect(get(:download, params: { id: 'dummy' })).to redirect_to(root_path)
      end
    end
  end
end
