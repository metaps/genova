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
        allow(Genova::Command::Executor).to receive(:call)
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
          it 'should return execute result' do
            image_info[:Labels][Genova::Docker::Client::BUILD_KEY] = 'build_key'

            expect { Genova::Docker::ImageCleaner.call }.not_to raise_error
            expect(image).to have_received(:remove).once
          end
        end

        context 'when there is a <none> image' do
          let(:repo_tags) { ['<none>:<none>'] }

          it 'should return execute result' do
            expect { Genova::Docker::ImageCleaner.call }.not_to raise_error
            expect(image).to have_received(:remove).once
          end
        end

        context 'build cache' do
          it 'prunes build cache older than the retention period' do
            Genova::Docker::ImageCleaner.call

            expect(Genova::Command::Executor).to have_received(:call).with(
              a_string_matching(/\Adocker builder prune --force --filter until=\d+h\z/),
              anything
            )
          end

          it 'does not abort when pruning fails' do
            allow(Genova::Command::Executor).to receive(:call).and_raise(StandardError, 'boom')

            expect { Genova::Docker::ImageCleaner.call }.not_to raise_error
          end
        end
      end
    end
  end
end
