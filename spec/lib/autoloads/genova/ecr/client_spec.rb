require 'rails_helper'

module Genova
  module Ecr
    describe Client do
      let(:ecr) { double(Aws::ECR::Client) }
      let(:ecr_client) { Ecr::Client.new(::Logger.new($stdout)) }

      before do
        allow(Aws::ECR::Client).to receive(:new).and_return(ecr)
      end

      describe 'authenticate' do
        it 'shuold be return true' do
          authorization_token = Base64.strict_encode64('username:password')
          allow(ecr).to receive(:get_authorization_token).and_return(authorization_data: [{ authorization_token: }])

          allow(::Docker).to receive(:authenticate!).and_return(true)

          expect(ecr_client.authenticate).to eq(true)
        end
      end

      describe 'push_image' do
        let(:image) { double(::Docker::Image) }

        before do
          allow(image).to receive(:tag)
          allow(image).to receive(:push)
          allow(::Docker::Image).to receive(:get).and_return(image)
        end

        context 'when repository exist.' do
          it 'should image push' do
            allow(ecr).to receive(:describe_repositories).and_return(repositories: [{ repository_name: 'repository' }])

            ecr_client.push_image('imsage_tag', 'repository')
            expect(image).to have_received(:push).twice
          end
        end

        context 'when repository not exist.' do
          context 'when the create_repository parameter is true' do
            it 'should image push' do
              allow(ecr).to receive(:describe_repositories).and_return(repositories: [])
              allow(ecr).to receive(:create_repository)

              ecr_client.push_image('image_tag', 'repository')
              expect(image).to have_received(:push).twice
            end
          end

          context 'when the create_repository parameter is false' do
            it 'should return error' do
              allow(Settings.ecr).to receive(:create_repository).and_return(false)
              allow(ecr).to receive(:describe_repositories).and_return(repositories: [])
              allow(Aws::ECR::Client).to receive(:new).and_return(ecr)

              expect { ecr_client.push_image('image_tag', 'repository') }.to raise_error(Exceptions::ValidationError)
            end
          end
        end
      end
    end
  end
end
