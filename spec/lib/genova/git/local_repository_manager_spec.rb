require 'rails_helper'

module Genova
  module Git
    describe LocalRepositoryManager do
      let(:manager) { Genova::Git::LocalRepositoryManager.new('account', 'repository') }

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

          expect(manager.load_deploy_config).to be_a(Genova::Config::DeployConfig)
        end
      end

      describe 'task_definition_config_path' do
        it 'should be return task definition path' do
          expect(manager.task_definition_config_path('cluster', 'service')).to eq(manager.path + '/config/deploy/service.yml')
        end
      end

      describe 'open_task_definition_config' do
        it 'should be return config' do
          allow(manager).to receive(:update)
          allow(File).to receive(:read).and_return('{}')

          expect(manager.open_task_definition_config('cluster', 'service')).to be_a(Genova::Config::TaskDefinitionConfig)
        end
      end

      describe 'origin_branches' do
        it 'should be return origin branches' do
          branch_mock1 = double(::Git::Branch)
          allow(branch_mock1).to receive(:name).and_return('master')

          branch_mock2 = double(::Git::Branch)
          allow(branch_mock2).to receive(:name).and_return('->')

          branches_mock = double(::Git::Branches)
          allow(branches_mock).to receive(:remote).and_return([branch_mock1, branch_mock2])

          git_mock = double(::Git)
          allow(git_mock).to receive(:fetch)
          allow(git_mock).to receive(:branches).and_return(branches_mock)
          allow(::Git).to receive(:open).and_return(git_mock)

          expect(manager.origin_branches.size).to eq(1)
        end
      end
    end
  end
end
