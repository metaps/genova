require 'rails_helper'

module Genova
  module Ecr
    describe Client do
      let(:ecr) { double(Aws::ECR::Client) }
      let(:ecr_client) { Ecr::Client.new }

      describe 'authenticate' do
        it 'shuold be return true' do
          authorization_token = Base64.strict_encode64('username:password')
          allow(ecr).to receive(:get_authorization_token).and_return(authorization_data: [{ authorization_token: }])
          allow(Aws::ECR::Client).to receive(:new).and_return(ecr)

          allow(::Docker).to receive(:authenticate!).and_return(true)

          expect(ecr_client.authenticate).to eq(true)
        end
      end

      describe 'push_image' do
        it 'should be image push' do
          allow(ecr).to receive(:describe_repositories).and_return(repositories: [{ repository_name: 'repository' }])
          allow(Aws::ECR::Client).to receive(:new).and_return(ecr)

          image = double(::Docker::Image)
          allow(image).to receive(:tag)
          allow(image).to receive(:push)
          allow(::Docker::Image).to receive(:get).and_return(image)

          ecr_client.push_image('image_tag', 'repository')
          expect(image).to have_received(:push).twice
        end
      end
    end
  end
end
