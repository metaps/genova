require 'rails_helper'

describe ApplicationController do
  describe 'restrict_remote_ip' do
    let(:request_mock) { double('ActionDispatch::Request') }

    controller do
      def index
        render plain: 'dummy content'
      end
    end

    it 'should be return success' do
      get :index
      expect(response).to have_http_status(:ok)
    end
  end
end
