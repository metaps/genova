require 'rails_helper'

module Genova
  module Sidekiq
    describe JobStore do
      let(:params) { { key: 'value' } }

      before do
        key = Genova::Sidekiq::JobStore.send(:generate_key, 'id')
        Genova::RedisPool.get.del(key)
      end

      describe 'create' do
        it 'should return store id' do
          expect(Genova::Sidekiq::JobStore.create('id', params)).to match(/^job_store_\w+$/)
        end
      end

      describe 'find' do
        it 'should return store value' do
          id = Genova::Sidekiq::JobStore.create('id', params)
          value = Genova::Sidekiq::JobStore.find(id)

          expect(value).to be_a(Hash)
          expect(value[:key]).to eq('value')
        end

        context 'when value contains Oj object mode keys' do
          let(:params) { { key: { '^o' => 'Object' }, symbol: ':value' } }

          it 'should return plain values' do
            id = Genova::Sidekiq::JobStore.create('id', params)
            value = Genova::Sidekiq::JobStore.find(id)

            expect(value[:key]).to eq('^o': 'Object')
            expect(value[:symbol]).to eq(':value')
          end
        end
      end
    end
  end
end
