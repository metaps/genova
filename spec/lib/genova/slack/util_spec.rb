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
          git_branch_mock = double('Git::Branch')
          allow(git_branch_mock).to receive(:name).and_return('feature/branch')

          deploy_client_mock = double('Genova::Deploy::Client')
          allow(deploy_client_mock).to receive(:fetch_repository)
          allow(deploy_client_mock).to receive(:fetch_branches).and_return([git_branch_mock])
          allow(Genova::Deploy::Client).to receive(:new).and_return(deploy_client_mock)

          results = Genova::Slack::Util.branch_options('account', 'repository')
          expect(results[0][:text]).to eq('feature/branch')
          expect(results[0][:value]).to eq('feature/branch')
        end
      end
    end
  end
end
