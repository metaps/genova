require 'rails_helper'

RSpec.describe DeployJobsController, type: :controller do
  describe 'GET #index' do
    it 'should be return success' do
      get :index
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #show' do
    context 'when log does not exist' do
      it 'should be return success' do
        expect(get :show, params: { id: 'dummy' }).to have_http_status(:not_found)
      end
    end
  end
end
