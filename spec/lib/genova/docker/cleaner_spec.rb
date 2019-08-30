require 'rails_helper'

module Genova
  module Docker
    describe Cleaner do
      describe 'execute' do
        let(:container_mock) { double(::Docker::Container) }
        let(:image_mock) { double(::Docker::Image) }

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

          Genova::Docker::Cleaner.execute
        end
      end
    end
  end
end
