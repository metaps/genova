require 'rails_helper'

module Genova
  module App
    describe Client do
      let(:code_manager) { CodeManager::Git.new('account', 'repository', branch: 'master') }
      let(:deploy_config_mock) { double(Genova::Config::DeployConfig) }

      describe 'pull' do
        let(:git_mock) { double(::Git) }

        it 'should be get latest source' do
          allow(code_manager).to receive(:clone)
          allow(git_mock).to receive(:fetch)
          allow(git_mock).to receive(:clean)
          allow(git_mock).to receive(:checkout)
          allow(git_mock).to receive(:branch)
          allow(git_mock).to receive(:reset_hard)
          allow(git_mock).to receive(:log)
          allow(code_manager).to receive(:client).and_return(git_mock)

          expect { code_manager.update }.to_not raise_error
        end
      end

      describe 'load_deploy_config' do
        it 'should be return config' do
          allow(code_manager).to receive(:update)
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:read).and_return('{}')

          deploy_config_mock = double(Genova::Config::DeployConfig)
          allow(Genova::Config::DeployConfig).to receive(:new).and_return(deploy_config_mock)

          expect(code_manager.load_deploy_config).to be_a(deploy_config_mock.class)
        end
      end

      describe 'task_definition_config_path' do
        it 'should be return task definition path' do
          expect(code_manager.task_definition_config_path('./config/deploy/path.yml')).to eq("#{code_manager.base_path}/config/deploy/path.yml")
        end
      end

      describe 'load_task_definition_config' do
        it 'should be return config' do
          allow(code_manager).to receive(:task_definition_config_path)
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:read).and_return('{}')

          expect(code_manager.load_task_definition_config('path')).to be_a(Genova::Config::TaskDefinitionConfig)
        end
      end

      describe 'origin_branches' do
        let(:git_mock) { double(::Git) }

        it 'should be return origin branches' do
          allow(code_manager).to receive(:clone)

          branch_mock_1 = double(::Git::Branch)
          allow(branch_mock_1).to receive(:name).and_return('master')

          branch_mock_2 = double(::Git::Branch)
          allow(branch_mock_2).to receive(:name).and_return('->')

          branches_mock = double(::Git::Branches)
          allow(branches_mock).to receive(:remote).and_return([branch_mock_1, branch_mock_2])

          allow(git_mock).to receive(:fetch)
          allow(git_mock).to receive(:branches).and_return(branches_mock)
          allow(code_manager).to receive(:client).and_return(git_mock)

          expect(code_manager.origin_branches.size).to eq(1)
        end
      end

      describe 'find_commit' do
        let(:git_mock) { double(::Git) }
        let(:tag_mock) { double(::Git::Object::Tag) }

        it 'should be return commit id' do
          allow(code_manager).to receive(:clone)
          allow(git_mock).to receive(:fetch)
          allow(tag_mock).to receive(:sha).and_return('id')
          allow(git_mock).to receive(:tag).and_return(tag_mock)
          allow(code_manager).to receive(:client).and_return(git_mock)

          expect(code_manager.find_commit('tag')).to eq('id')
        end
      end
    end
  end
end
