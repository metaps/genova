require 'rails_helper'

describe Genova::Docker::Registry do
  let(:logger) { Logger.new(nil) }
  let(:registry_settings) do
    OpenStruct.new(
      url: 'dhi.io',
      username: nil,
      password: nil,
      pull_images: ['dhi.io/org/app:base']
    )
  end
  let(:docker_settings) { OpenStruct.new(registry: registry_settings) }

  subject(:registry) { described_class.new(logger) }

  before do
    allow(Settings).to receive(:dig).with(:docker, :registry).and_return(registry_settings)
    allow(Settings).to receive(:docker).and_return(docker_settings)
    allow(Genova::Command::Executor).to receive(:call).and_return(0)
  end

  describe '#login_and_pull' do
    context 'when credentials are provided via env' do
      before do
        allow(ENV).to receive(:[]).with('DOCKER_REGISTRY_USER').and_return('user1')
        allow(ENV).to receive(:[]).with('DOCKER_REGISTRY_PASSWORD').and_return('pass1')
      end

      it 'executes docker login with filtered password and pulls images' do
        registry.login_and_pull

        expect(Genova::Command::Executor).to have_received(:call).with(
          a_string_matching(/docker login dhi\.io/),
          logger,
          hash_including(:filtered_command)
        )
        expect(Genova::Command::Executor).to have_received(:call).with('docker pull dhi.io/org/app:base', logger)
      end
    end

    context 'when credentials are missing' do
      before do
        allow(ENV).to receive(:[]).and_return(nil)
        registry_settings.username = nil
        registry_settings.password = nil
      end

      it 'skips login and pull' do
        registry.login_and_pull
        expect(Genova::Command::Executor).not_to have_received(:call)
      end
    end
  end
end
