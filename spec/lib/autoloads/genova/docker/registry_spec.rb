require 'rails_helper'

describe Genova::Docker::Registry do
  let(:logger) { Logger.new(nil) }
  let(:registry_settings) do
    OpenStruct.new(
      url: 'dhi.io',
      username: nil,
      password: nil,
      username_secret: nil,
      password_secret: nil,
      pull_images: ['dhi.io/org/app:base']
    )
  end

  subject(:registry) { described_class.new(logger) }

  before do
    allow(Settings).to receive(:dig).with(:docker, :registry).and_return(registry_settings)
    allow(Genova::Command::Executor).to receive(:call).and_return(0)
    allow(ENV).to receive(:[]).with('DOCKER_REGISTRY_URL').and_return(nil)
    allow(ENV).to receive(:[]).with('DOCKER_REGISTRY_USER').and_return(nil)
    allow(ENV).to receive(:[]).with('DOCKER_REGISTRY_PASSWORD').and_return(nil)
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

    context 'when credentials are provided via Secrets Manager and SSM' do
      before do
        registry_settings.username_secret = 'arn:aws:secretsmanager:ap-northeast-1:000000000000:secret:docker-user'
        registry_settings.password_secret = '/docker/password'
      end

      it 'resolves credentials and executes docker login' do
        registry.login_and_pull

        expect(Genova::Command::Executor).to have_received(:call).with(
          "echo #{Shellwords.escape('PSParameterValue')} | docker login dhi.io -u #{Shellwords.escape('SecretStringType')} --password-stdin",
          logger,
          hash_including(filtered_command: 'echo {FILTERED} | docker login dhi.io -u {FILTERED} --password-stdin')
        )
      end
    end

    context 'when credentials are missing' do
      before do
        registry_settings.username = nil
        registry_settings.password = nil
      end

      it 'skips login and pull' do
        registry.login_and_pull
        expect(Genova::Command::Executor).not_to have_received(:call)
      end
    end

    context 'when docker login fails' do
      before do
        allow(ENV).to receive(:[]).with('DOCKER_REGISTRY_USER').and_return('user1')
        allow(ENV).to receive(:[]).with('DOCKER_REGISTRY_PASSWORD').and_return('pass1')
        allow(Genova::Command::Executor).to receive(:call).and_return(1)
      end

      it 'raises validation error' do
        expect { registry.login_and_pull }.to raise_error(Genova::Exceptions::ValidationError, 'Docker registry login failed. [dhi.io]')
      end
    end
  end
end
