require 'rails_helper'

RSpec.describe LogsController, type: :controller do
  describe 'GET #index' do
    it 'should be return success' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(response).to render_template('logs/index')
    end
  end

  describe 'GET #show' do
    context 'when log does not exist' do
      it 'should be return success' do
        expect { get :show, params: { id: 'dummy' } }.to raise_error(Mongoid::Errors::DocumentNotFound)
      end
    end
  end
end
