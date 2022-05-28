require 'rails_helper'

module Genova
  module Sidekiq
    describe JobStore do
      let(:params) { { key: 'value' } }

      before do
        key = Genova::Sidekiq::JobStore.send(:generate_key, 'id')
        Redis.current.del(key)
      end

      describe 'create' do
        it 'should be return store id' do
          expect(Genova::Sidekiq::JobStore.create('id', params)).to match(/^job_store_\w+$/)
        end
      end

      describe 'find' do
        it 'should be return store value' do
          id = Genova::Sidekiq::JobStore.create('id', params)
          value = Genova::Sidekiq::JobStore.find(id)

          expect(value).to be_a(Hash)
          expect(value[:key]).to eq('value')
        end
      end
    end
  end
end
