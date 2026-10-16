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
    ['', '   '].each do |value|
      context "when registry environment values are #{value.inspect}" do
        before do
          %w[DOCKER_REGISTRY_URL DOCKER_REGISTRY_USER DOCKER_REGISTRY_PASSWORD].each do |key|
            allow(ENV).to receive(:[]).with(key).and_return(value)
          end
        end

        it 'uses configured credentials and pulls images' do
          registry_settings.username = 'configured-user'
          registry_settings.password = 'configured-password'

          registry.login_and_pull

          expect(Genova::Command::Executor).to have_received(:call).with(
            'echo configured-password | docker login dhi.io -u configured-user --password-stdin',
            logger,
            hash_including(:filtered_command)
          )
          expect(Genova::Command::Executor).to have_received(:call).with('docker pull dhi.io/org/app:base', logger)
        end

        it 'resolves secret references and pulls images' do
          registry_settings.username_secret = 'arn:aws:secretsmanager:ap-northeast-1:000000000000:secret:docker-user'
          registry_settings.password_secret = '/docker/password'

          registry.login_and_pull

          expect(Genova::Command::Executor).to have_received(:call).with(
            'echo PSParameterValue | docker login dhi.io -u SecretStringType --password-stdin',
            logger,
            hash_including(:filtered_command)
          )
          expect(Genova::Command::Executor).to have_received(:call).with('docker pull dhi.io/org/app:base', logger)
        end
      end
    end

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

    context 'when registry configuration is absent' do
      let(:registry_settings) { nil }

      it 'skips login and pull' do
        registry.login_and_pull

        expect(Genova::Command::Executor).not_to have_received(:call)
      end
    end

    context 'when credentials and pull images are missing' do
      before do
        registry_settings.pull_images = []
      end

      it 'logs a warning and skips login and pull' do
        expect(logger).to receive(:warn).with('Docker registry login skipped because URL, username or password is missing.')

        registry.login_and_pull
        expect(Genova::Command::Executor).not_to have_received(:call)
      end
    end

    context 'when registry settings are empty' do
      before do
        registry_settings.url = nil
        registry_settings.pull_images = []
      end

      it 'skips login and pull without a warning' do
        expect(logger).not_to receive(:warn)

        registry.login_and_pull

        expect(Genova::Command::Executor).not_to have_received(:call)
      end
    end

    %i[url username password].each do |key|
      [nil, '', '   '].each do |value|
        context "when pulls are configured and #{key} is #{value.inspect}" do
          before do
            registry_settings.username = 'configured-user'
            registry_settings.password = 'configured-password'
            registry_settings[key] = value
          end

          it 'raises validation error without running Docker commands' do
            expect(logger).to receive(:warn).with('Docker registry login skipped because URL, username or password is missing.')

            expect { registry.login_and_pull }.to raise_error(
              Genova::Exceptions::ValidationError,
              'Docker registry URL, username and password are required to pull images.'
            )
            expect(Genova::Command::Executor).not_to have_received(:call)
          end
        end
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
