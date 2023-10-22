require 'rails_helper'

describe ApplicationController do
  describe '#render_404' do
    it 'should return HTTP 404 status' do
      get :render_404, params: { path: 'non_existent_path' }
      expect(response).to have_http_status(:not_found)
    end
  end
end
