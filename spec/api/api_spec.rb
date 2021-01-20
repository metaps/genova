require 'rails_helper'

describe Api do
  describe 'helpers' do
    describe 'logger' do
    end
  end

  describe 'GET /' do
    it 'should be return success' do
      get '/api'
      expect(response).to have_http_status :ok
      expect(response.body).to be_json_eql('success'.to_json).at_path('result')
    end
  end
end
