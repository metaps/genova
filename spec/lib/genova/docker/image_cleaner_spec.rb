require 'rails_helper'

module Genova
  module Docker
    describe ImageCleaner do
      describe 'call' do
        let(:image_mock) { double(::Docker::Image) }
        let(:container_mock) { double(::Docker::Container) }

        it 'should be return execute result' do
          allow(container_mock).to receive(:info).and_return({
            ImageID: 'image_id'
          }.stringify_keys)
          allow(::Docker::Container).to receive(:all).and_return([container_mock])

          allow(Settings.docker).to receive(:retention_days).and_return(1)

          allow(image_mock).to receive(:info).and_return({
            Created: Time.new.utc.to_i - 60 * 60 * 24 - 1
          }.stringify_keys)
          allow(image_mock).to receive(:id).and_return('id')
          allow(image_mock).to receive(:remove)
          allow(::Docker::Image).to receive(:all).and_return([image_mock])
          allow(::Docker::Image).to receive(:prune).and_return([])

          expect { Genova::Docker::ImageCleaner.call }.not_to raise_error
        end
      end
    end
  end
end
