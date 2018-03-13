require 'rails_helper'

module Genova
  module Deploy
    describe Client, :logged_in => true do
      before(:each) do
        DeployJob.delete_all
      end

      let(:deploy_config_mock) { double('Genova::Deploy::Config::DeployConfig') }
      let(:deploy_client) do
        allow(Aws::ECR::Client).to receive(:new).and_return(double(Aws::ECR::Client))
        allow(File).to receive(:exist?).with('id_rsa').and_return(true)
        allow(EcsDeployer::Client).to receive(:new)

        allow_any_instance_of(Genova::Github::Client).to receive(:fetch_last_commit_id)
        allow(Genova::Deploy::Config::DeployConfig).to receive(:new)

        allow(deploy_config_mock).to receive(:cluster_name).and_return('cluster_name')
        client = Client.new(Genova::Deploy::Client.mode.find_value(:manual).to_sym, 'sandbox', ssh_secret_key_path: 'id_rsa')
        allow(client).to receive(:config).and_return(deploy_config_mock)

        allow(Settings.github.account).to receive(:[]).and_return('metaps')

        client
      end
      let(:command) { deploy_client.instance_variable_get(:@command) }
      let(:logger) { deploy_client.instance_variable_get(:@logger) }

      describe 'initialize' do
        context 'when argument is valid' do
          it 'should be return Client' do
            expect(deploy_client).to be_a(Client)
          end

          it 'should be return options' do
            options = deploy_client.instance_variable_get(:@options)
            expect(options[:account]).to eq('metaps')
            expect(options[:branch]).to eq('master')
            expect(options[:interactive]).to be_falsey
            expect(options[:profile]).to eq('default')
            expect(options[:push_only]).to be_falsey
            expect(options[:region]).to eq('ap-northeast-1')
            expect(options[:verbose]).to be_falsey
          end
        end
      end

      describe 'exec' do
        context 'when "push_only" option is false' do
          it 'should be deploy' do
            allow_any_instance_of(Client).to receive(:fetch_source)
            allow(File).to receive(:exist?).and_return(true)
            allow(File).to receive(:read).and_return('{}')

            git_mock = double(Git)
            allow(git_mock).to receive(:log).and_return(['commit_id'])
            allow(Git).to receive(:open).and_return(git_mock)

            task_definition_mock = double(Aws::ECS::Types::TaskDefinition)
            allow(task_definition_mock).to receive(:task_definition_arn)

            allow_any_instance_of(Client).to receive(:build_images)
            allow_any_instance_of(Client).to receive(:push_images)
            allow_any_instance_of(Client).to receive(:deploy).and_return(task_definition_mock)
            allow_any_instance_of(Client).to receive(:cleanup_images)

            expect(deploy_client.exec('development')).to be_a(task_definition_mock.class)
            expect(deploy_client).to have_received(:build_images)
            expect(deploy_client).to have_received(:push_images)
            expect(deploy_client).to have_received(:deploy)
            expect(deploy_client).to have_received(:cleanup_images)
          end
        end

        context 'when "push_only" option is true' do
          it 'should be push only' do
            options = deploy_client.instance_variable_get(:@options)
            options[:push_only] = true

            allow_any_instance_of(Client).to receive(:fetch_source)
            allow(File).to receive(:exist?).and_return(true)
            allow(File).to receive(:read).and_return('{}')

            git_mock = double(Git)
            allow(git_mock).to receive(:log).and_return(['commit_id'])
            allow(Git).to receive(:open).and_return(git_mock)

            allow_any_instance_of(Client).to receive(:build_images)
            allow_any_instance_of(Client).to receive(:push_images)
            allow_any_instance_of(Client).to receive(:cleanup_images)

            expect(deploy_client.exec('development')).to eq(nil)
            expect(deploy_client).to have_received(:build_images)
            expect(deploy_client).to have_received(:push_images)
          end
        end
      end

      describe 'fetch_repository' do
        context 'when not exist repository' do
          it 'should be clone repository' do
            allow(Dir).to receive(:exist?).with("#{Rails.root}/tmp/repos/metaps/sandbox").and_return(false)
            allow(Dir).to receive(:exist?).with("#{Rails.root}/tmp/repos/metaps").and_return(true)
            allow(Git).to receive(:clone)

            deploy_client.fetch_repository
            expect(Git).to have_received(:clone).once
          end
        end
      end

      describe 'fetch_branches' do
        it 'should be return remote branches' do
          git_branches_mock = double(Git::Branches)
          allow(git_branches_mock).to receive(:remote).and_return([])

          git_mock = double(Git)
          allow(git_mock).to receive(:fetch)
          allow(git_mock).to receive(:branches).and_return(git_branches_mock)
          allow(Git).to receive(:open).and_return(git_mock)
          expect(deploy_client.fetch_branches.class).to eq(Array)
        end
      end

      describe 'deploy_config' do
        it 'should be return Genova::Deploy::Config::DeployConfig' do
          expect(deploy_client.config).to eq(deploy_config_mock)
        end
      end
    end
  end
end
