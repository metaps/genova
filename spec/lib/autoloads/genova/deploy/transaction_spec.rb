require 'rails_helper'

module Genova
  module Deploy
    describe Transaction do
      let(:transaction) { Genova::Deploy::Transaction.new('repository_name') }

      before do
        stub_const('Genova::Deploy::Transaction::LOCK_WAIT_INTERVAL', 1)
        allow(Settings.github).to receive(:deploy_lock_timeout).and_return(1)
      end

      describe '#begin' do
        it 'should start a transaction' do
          expect(transaction.begin).to be_truthy
        end

        it 'should handle transaction conflict' do
          transaction = Genova::Deploy::Transaction.new('repository_name')
          allow(transaction).to receive(:running?).and_return(true)

          expect { transaction.begin }.to raise_error(Genova::Exceptions::DeployLockError)
        end
      end

      describe '#running?' do
        it 'should return false when no transaction is running' do
          expect(transaction.running?).to be_falsey
        end

        it 'should return true when a transaction is running' do
          transaction.begin
          expect(transaction.running?).to be_truthy
        end
      end

      describe '#commit' do
        it 'should complete the transaction' do
          transaction = Genova::Deploy::Transaction.new('repository_name')
          allow(Genova::RedisPool.get).to receive(:del)
          
          expect(transaction.commit).to be_nil
        end
      end

      describe '#cancel' do
        it 'should cancel the transaction' do
          transaction = Genova::Deploy::Transaction.new('repository_name')
          
          expect(Genova::RedisPool.get.get("trans_#{Settings.github.account}")).to be_nil
        end
      end
    end
  end
end
