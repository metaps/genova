require 'rails_helper'

module Genova
  module Ecr
    describe Client do
      let(:ecr_mock) { double(Aws::ECR::Client) }
      let(:ecr_client) { Ecr::Client.new }

      describe 'authenticate' do
        it 'shuold be return true' do
          authorization_token = Base64.strict_encode64('username:password')
          allow(ecr_mock).to receive(:get_authorization_token).and_return(authorization_data: [{ authorization_token: authorization_token }])
          allow(Aws::ECR::Client).to receive(:new).and_return(ecr_mock)

          allow(::Docker).to receive(:authenticate!).and_return(true)

          expect(ecr_client.authenticate).to eq(true)
        end
      end

      describe 'push_image' do
        it 'should be image push' do
          allow(ecr_mock).to receive(:describe_repositories).and_return(repositories: [{ repository_name: 'repository' }])
          allow(Aws::ECR::Client).to receive(:new).and_return(ecr_mock)

          image_mock = double(::Docker::Image)
          allow(image_mock).to receive(:tag)
          allow(image_mock).to receive(:push)
          allow(::Docker::Image).to receive(:get).and_return(image_mock)

          ecr_client.push_image('image_tag', 'repository')
          expect(image_mock).to have_received(:push).twice
        end
      end
    end
  end
end
