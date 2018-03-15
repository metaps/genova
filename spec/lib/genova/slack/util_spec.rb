require 'rails_helper'

module Genova
  module Slack
    describe Util do
      describe 'repository_options' do
        it 'should be return repository list' do
          allow(Settings.slack.interactive).to receive(:repositories).and_return([
                                                                                   'repository',
                                                                                   'metaps/repository'
                                                                                 ])
          results = Genova::Slack::Util.repository_options
          expect(results[0][:text]).to eq('repository')
          expect(results[0][:value]).to eq('metaps/repository')
          expect(results[1][:text]).to eq('metaps/repository')
          expect(results[1][:value]).to eq('metaps/repository')
        end
      end

      describe 'branch_options' do
        it 'should be return branch list' do
          repository_manager_mock = double('Genova::Git::LocalRepositoryMangaer')
          branch_mock = double('Git::Branch')

          allow(branch_mock).to receive(:name).and_return('feature/branch')
          allow(repository_manager_mock).to receive(:origin_branches).and_return([branch_mock])
          allow(Genova::Git::LocalRepositoryManager).to receive(:new).and_return(repository_manager_mock)

          results = Genova::Slack::Util.branch_options('account', 'repository')
          expect(results[0][:text]).to eq('feature/branch')
          expect(results[0][:value]).to eq('feature/branch')
        end
      end
    end
  end
end
