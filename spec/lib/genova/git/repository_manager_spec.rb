require 'rails_helper'

module Genova
  module Git
    describe RepositoryManager do
      let(:repository_manager) { Genova::Git::RepositoryManager.new('account', 'repository') }
      let(:deploy_config_mock) { double(Genova::Config::DeployConfig) }

      describe 'clone' do
        it 'should be execute git clone' do
          allow(Dir).to receive(:exist?).and_return(false)
          allow(FileUtils).to receive(:mkdir_p)
          allow(::Git).to receive(:clone)

          expect { repository_manager.clone }.to_not raise_error
        end
      end

      describe 'update' do
        let(:git_mock) { double(::Git) }

        it 'should be get latest source' do
          allow(repository_manager).to receive(:clone)
          allow(git_mock).to receive(:fetch)
          allow(git_mock).to receive(:clean)
          allow(git_mock).to receive(:checkout)
          allow(git_mock).to receive(:branch)
          allow(git_mock).to receive(:reset_hard)
          allow(git_mock).to receive(:log)
          allow(repository_manager).to receive(:client).and_return(git_mock)

          expect { repository_manager.update }.to_not raise_error
        end
      end

      describe 'load_deploy_config' do
        it 'should be return config' do
          allow(repository_manager).to receive(:update)
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:read).and_return('{}')

          expect { repository_manager.load_deploy_config }.to_not raise_error
        end
      end

      describe 'task_definition_config_path' do
        it 'should be return task definition path' do
          expect(repository_manager.task_definition_config_path('./config/deploy/path.yml')).to eq(repository_manager.base_path + '/config/deploy/path.yml')
        end
      end

      describe 'load_task_definition_config' do
        it 'should be return config' do
          allow(repository_manager).to receive(:task_definition_config_path)
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:read).and_return('{}')

          expect(repository_manager.load_task_definition_config('path')).to be_a(Genova::Config::TaskDefinitionConfig)
        end
      end

      describe 'origin_branches' do
        let(:git_mock) { double(::Git) }

        it 'should be return origin branches' do
          allow(repository_manager).to receive(:clone)

          branch_mock1 = double(::Git::Branch)
          allow(branch_mock1).to receive(:name).and_return('master')

          branch_mock2 = double(::Git::Branch)
          allow(branch_mock2).to receive(:name).and_return('->')

          branches_mock = double(::Git::Branches)
          allow(branches_mock).to receive(:remote).and_return([branch_mock1, branch_mock2])

          allow(git_mock).to receive(:fetch)
          allow(git_mock).to receive(:branches).and_return(branches_mock)
          allow(repository_manager).to receive(:client).and_return(git_mock)

          expect(repository_manager.origin_branches.size).to eq(1)
        end
      end

      describe 'find_commit_id' do
        let(:git_mock) { double(::Git) }

        it 'should be return commit id' do
          allow(repository_manager).to receive(:clone)
          allow(git_mock).to receive(:fetch)
          allow(git_mock).to receive(:tag).and_return('id')
          allow(repository_manager).to receive(:client).and_return(git_mock)

          expect(repository_manager.find_commit_id('tag')).to eq('id')
        end
      end
    end
  end
end
