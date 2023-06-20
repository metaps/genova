require 'rails_helper'

module Genova
  module Docker
    describe ImageCleaner do
      before do
        stub_const('Genova::Docker::ImageCleaner::RETENTION_SEC', 1)

        allow(container).to receive(:info).and_return({
          ImageID: 'image_id'
        }.stringify_keys)
        allow(::Docker::Container).to receive(:all).and_return([container])
        allow(image).to receive(:info).and_return(image_info.stringify_keys)
        allow(image).to receive(:id).and_return('id')
        allow(image).to receive(:remove)
        allow(::Docker::Image).to receive(:all).and_return([image])
      end

      let(:image) { double(::Docker::Image) }
      let(:container) { double(::Docker::Container) }
      let(:image_info) do
        {
          Created: Time.new.utc.to_i - 60 * 60 * 24 - 1,
          RepoTags: repo_tags,
          Labels: {}
        }
      end

      describe 'call' do
        let(:repo_tags) { ['latest'] }

        context 'when there is a built image' do
          it 'should be return execute result' do
            image_info[:Labels][Genova::Docker::Client::BUILD_KEY] = 'build_key'

            expect { Genova::Docker::ImageCleaner.call }.not_to raise_error
            expect(image).to have_received(:remove).once
          end
        end

        context 'when there is a <none> image' do
          let(:repo_tags) { ['<none>:<none>'] }

          it 'should be return execute result' do
            expect { Genova::Docker::ImageCleaner.call }.not_to raise_error
            expect(image).to have_received(:remove).once
          end
        end
      end
    end
  end
end
