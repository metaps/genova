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

    context 'when displaying build-only jobs' do
      render_views

      it 'labels the job as build-only in the list' do
        DeployJob.collection.drop
        deploy_job.update!(build_only: true, branch: 'develop')

        get :index

        expect(response.body).to include('Build only')
      end
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

      context 'when displaying the executor' do
        render_views

        it 'labels a build-only job and displays its registered task definition' do
          deploy_job.update!(build_only: true)

          get :show, params: { id: deploy_job.id }

          expect(response.body).to include('Build only', 'new_task_definition_arn')
        end

        it 'shows unknown for existing CLI records' do
          get :show, params: { id: deploy_job.id }

          expect(response.body).to include('Executor', 'unknown')
        end

        it 'escapes the CLI login user' do
          deploy_job.update!(linux_user_name: '<b>alice</b>')
          get :show, params: { id: deploy_job.id }

          expect(response.body).to include('Executor', '&lt;b&gt;alice&lt;/b&gt;')
          expect(response.body).not_to include('<b>alice</b>')
        end

        it 'shows the Slack user under the same label' do
          deploy_job.update!(mode: :slack, slack_user_name: 'slack-alice')
          get :show, params: { id: deploy_job.id }

          expect(response.body).to include('Executor', 'slack-alice')
          expect(response.body).not_to include('Slack user')
        end
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

      context 'when note starts with url and includes another line' do
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
            note: "https://example.com\naaaa"
          )
        end

        it 'renders only the url line as a link and keeps line breaks' do
          get :show, params: { id: deploy_job.id }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include('href="https://example.com"')
          expect(response.body).to include('>https://example.com</a><br')
          expect(response.body).to include('aaaa')
          expect(response.body).not_to include('href="https://example.com%0Aaaaa"')
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
