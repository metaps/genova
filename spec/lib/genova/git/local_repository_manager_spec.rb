require 'rails_helper'

module Genova
  module Git
    describe LocalRepositoryManager do
      let(:manager) { Genova::Git::LocalRepositoryManager.new('account', 'repository') }

      before(:each) do
        deploy_config_mock = double(Genova::Config::DeployConfig)
        allow(deploy_config_mock).to receive(:cluster).and_return({})
        allow(manager).to receive(:load_deploy_config).and_return(deploy_config_mock)
      end

      describe 'clone' do
        it 'should be execute git clone' do
          allow(Dir).to receive(:exist?).and_return(false)
          allow(FileUtils).to receive(:mkdir_p)

          allow(::Git).to receive(:clone)
          manager.clone
          expect(::Git).to have_received(:clone).once
        end
      end

      describe 'update' do
        it 'should be get latest source' do
          allow(::Git).to receive(:clone)

          git_mock = double(::Git)
          allow(git_mock).to receive(:branch)
          allow(git_mock).to receive(:fetch)
          allow(git_mock).to receive(:clean)
          allow(git_mock).to receive(:checkout)
          allow(git_mock).to receive(:reset_hard)
          allow(git_mock).to receive(:log)
          allow(::Git).to receive(:open).and_return(git_mock)

          manager.update
          expect(git_mock).to have_received(:fetch).once
          expect(git_mock).to have_received(:checkout).once
          expect(git_mock).to have_received(:clean).once
          expect(git_mock).to have_received(:reset_hard).once
        end
      end

      describe 'load_deploy_config' do
        it 'should be return config' do
          allow(manager).to receive(:update)
          allow(File).to receive(:read).and_return('{}')

          expect(manager.load_deploy_config.to_s).to eq(double(Genova::Config::DeployConfig).to_s)
        end
      end

      describe 'task_definition_config_path' do
        it 'should be return task definition path' do
          expect(manager.task_definition_config_path('./deploy/path.yml')).to eq(manager.base_path + '/config/deploy/path.yml')
        end
      end

      describe 'load_task_definition_config' do
        it 'should be return config' do
          allow(manager).to receive(:update)
          allow(File).to receive(:read).and_return('{}')
          allow(File).to receive(:exist?).and_return(true)

          expect(manager.load_task_definition_config('path')).to be_a(Genova::Config::TaskDefinitionConfig)
        end
      end

      describe 'origin_branches' do
        it 'should be return origin branches' do
          git_mock = double(::Git)

          allow(manager).to receive(:clone)
          allow(manager).to receive(:client).and_return(git_mock)

          branch_mock1 = double(::Git::Branch)
          allow(branch_mock1).to receive(:name).and_return('master')

          branch_mock2 = double(::Git::Branch)
          allow(branch_mock2).to receive(:name).and_return('->')

          branches_mock = double(::Git::Branches)
          allow(branches_mock).to receive(:remote).and_return([branch_mock1, branch_mock2])

          allow(git_mock).to receive(:fetch)
          allow(git_mock).to receive(:branches).and_return(branches_mock)

          expect(manager.origin_branches.size).to eq(1)
        end
      end

      describe 'origin_branches' do
        it 'should be return origin branches' do
          git_mock = double(::Git)

          allow(manager).to receive(:clone)
          allow(manager).to receive(:client).and_return(git_mock)

          branch_mock1 = double(::Git::Branch)
          allow(branch_mock1).to receive(:name).and_return('master')

          branch_mock2 = double(::Git::Branch)
          allow(branch_mock2).to receive(:name).and_return('->')

          branches_mock = double(::Git::Branches)
          allow(branches_mock).to receive(:remote).and_return([branch_mock1, branch_mock2])

          allow(git_mock).to receive(:fetch)
          allow(git_mock).to receive(:branches).and_return(branches_mock)

          expect(manager.origin_branches.size).to eq(1)
        end
      end
    end
  end
end
