require 'rails_helper'

module Genova
  module Ecr
    describe Client do
      let(:ecr_mock) { double(Aws::ECR::Client) }
      let(:ecr_client) { Genova::Ecr::Client.new(region: 'region') }

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

      describe 'destroy_images' do
        it 'should be destroy image' do
          image_detail_mocks = []

          (1..10).each do |i|
            image_detail_mock = double(Aws::ECR::Types::ImageDetail)
            allow(image_detail_mock).to receive(:image_pushed_at).and_return(Time.new.utc - i.days)
            allow(image_detail_mock).to receive(:image_digest).and_return('image_digest')
            image_detail_mocks << image_detail_mock
          end

          describe_images_mock = double(Aws::ECR::Types::DescribeImagesResponse)
          allow(describe_images_mock).to receive(:image_details).and_return(image_detail_mocks)
          allow(describe_images_mock).to receive(:next_token)

          allow(ecr_mock).to receive(:describe_images).and_return(describe_images_mock)

          batch_delete_image_response_mock = double(Aws::ECR::Types::BatchDeleteImageResponse)
          allow(batch_delete_image_response_mock).to receive(:image_ids).and_return(image_detail_mocks)
          allow(batch_delete_image_response_mock).to receive(:failures).and_return([])

          allow(ecr_mock).to receive(:batch_delete_image).and_return(batch_delete_image_response_mock)
          allow(Aws::ECR::Client).to receive(:new).and_return(ecr_mock)

          allow(Settings.aws.service.ecr).to receive(:max_image_size).and_return(3)

          expect { ecr_client.destroy_images(['repository_name']) }.to_not raise_error
        end
      end
    end
  end
end
