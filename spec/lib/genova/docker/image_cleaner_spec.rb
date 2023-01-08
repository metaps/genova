require 'rails_helper'

module Genova
  module Docker
    describe ImageCleaner do
      describe 'call' do
        let(:image) { double(::Docker::Image) }
        let(:container) { double(::Docker::Container) }

        it 'should be return execute result' do
          allow(container).to receive(:info).and_return({
            ImageID: 'image_id'
          }.stringify_keys)
          allow(::Docker::Container).to receive(:all).and_return([container])

          allow(Settings.docker).to receive(:retention_days).and_return(1)

          allow(image).to receive(:info).and_return({
            Created: Time.new.utc.to_i - 60 * 60 * 24 - 1
          }.stringify_keys)
          allow(image).to receive(:id).and_return('id')
          allow(image).to receive(:remove)
          allow(::Docker::Image).to receive(:all).and_return([image])

          expect { Genova::Docker::ImageCleaner.call }.not_to raise_error
        end
      end
    end
  end
end
