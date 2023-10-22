require 'rails_helper'

module Genova
  module CodeManager
    describe Git do
      let(:git) { double(::Git) }

      before do
        allow(File).to receive(:file?).and_return(true)
        allow(FileUtils).to receive(:rm_rf)
        allow(::Git).to receive(:clone)
        allow(::Git).to receive(:open).and_return(git)
      end

      let(:code_manager) { CodeManager::Git.new('repository', branch: 'master') }
      let(:deploy_config) { double(Genova::Config::DeployConfig) }

      describe 'pull' do
        it 'should get latest source' do
          allow(code_manager).to receive(:clone)
          allow(git).to receive(:fetch)
          allow(git).to receive(:clean)
          allow(git).to receive(:checkout)
          allow(git).to receive(:branch)
          allow(git).to receive(:reset_hard)
          allow(git).to receive(:submodule_update)
          allow(git).to receive(:log)

          expect { code_manager.update }.to_not raise_error
        end
      end

      describe 'load_deploy_config' do
        let(:config) { { clusters: [] } }

        it 'should return config' do
          allow(code_manager).to receive(:fetch_config).and_return({ clusters: [] })

          expect(code_manager.load_deploy_config).to be_a(Genova::Config::DeployConfig)
        end
      end

      describe 'task_definition_config_path' do
        it 'should return task definition path' do
          expect(code_manager.task_definition_config_path('./config/deploy/path.yml')).to eq("#{code_manager.base_path}/config/deploy/path.yml")
        end
      end

      describe 'origin_branches' do
        it 'should return origin branches' do
          allow(code_manager).to receive(:clone)

          branch_1 = double(::Git::Branch)
          allow(branch_1).to receive(:name).and_return('master')

          branch_2 = double(::Git::Branch)
          allow(branch_2).to receive(:name).and_return('->')

          branches = double(::Git::Branches)
          allow(branches).to receive(:remote).and_return([branch_1, branch_2])

          allow(git).to receive(:fetch)
          allow(git).to receive(:branches).and_return(branches)

          expect(code_manager.origin_branches.size).to eq(1)
        end
      end

      describe 'find_commit' do
        let(:tag) { double(::Git::Object::Tag) }

        it 'should return commit id' do
          allow(code_manager).to receive(:clone)
          allow(git).to receive(:fetch)
          allow(tag).to receive(:sha).and_return('id')
          allow(git).to receive(:tag).and_return(tag)

          expect(code_manager.find_commit('tag')).to eq('id')
        end
      end

      describe 'release' do
        it 'should tag sent' do
          allow(code_manager).to receive(:update)
          allow(git).to receive(:add_tag)
          allow(git).to receive(:push)

          expect { code_manager.release('tag', 'commit') }.to_not raise_error
          expect(git).to have_received(:push).once
        end
      end

      describe 'default_branch' do
        context 'when correct response is returned' do
          it 'should return default branch' do
            allow(git).to receive(:remote_show_origin).and_return('HEAD branch: main')
            expect(code_manager.default_branch).to eq('main')
          end
        end

        context 'when invalid response is returned' do
          it 'should return default branch' do
            allow(git).to receive(:remote_show_origin).and_return('invalid')
            expect(code_manager.default_branch).to eq(nil)
          end
        end
      end
    end
  end
end
