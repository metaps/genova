require 'rails_helper'

module Genova
  module Docker
    describe Cleaner do
      describe 'execute' do
        let(:container_mock) { double(::Docker::Container) }
        let(:image_mock) { double(::Docker::Image) }
        let(:logger_mock) { double(::Logger) }

        it 'should be return execute result' do
          # cleanup_unused_containers
          allow(container_mock).to receive(:info).and_return({
            State: 'exited',
            ImageID: 'use'
          }.stringify_keys)
          allow(container_mock).to receive(:id)
          allow(container_mock).to receive(:remove)

          # cleanup_unused_images
          allow(::Docker::Container).to receive(:all).and_return([container_mock])

          allow(Settings.docker).to receive(:retention_days).and_return(1)

          allow(image_mock).to receive(:info).and_return({
            Created: Time.new.utc.to_i - 60 * 60 * 24 - 1,
            RepoTags: ['<none>:<none>']
          }.stringify_keys)
          allow(image_mock).to receive(:id).and_return('unuse')
          allow(image_mock).to receive(:remove)
          allow(::Docker::Image).to receive(:all).and_return([image_mock])

          # cleanup_unused_networks
          allow(::Docker::Network).to receive(:prune)

          # cleanup_unused_volumes
          allow(::Docker::Volume).to receive(:prune)

          allow(logger_mock).to receive(:info)
          allow(::Logger).to receive(:new).and_return(logger_mock)

          expect { Genova::Docker::Cleaner.execute }.not_to raise_error
          expect(logger_mock).to have_received(:info).exactly(7).times
        end
      end
    end
  end
end
