require 'rails_helper'

module Genova
  module Sidekiq
    describe Queue do
      let(:params) { { key: 'value' } }

      describe 'add' do
        it 'should be return queue id' do
          expect(Genova::Sidekiq::Queue.add(params)).to match(/^job_\d+$/)
        end
      end

      describe 'find' do
        it 'should be return queue value' do
          id = Genova::Sidekiq::Queue.add(params)
          job = Genova::Sidekiq::Queue.find(id)

          expect(job).to be_a(Genova::Sidekiq::Job)
          expect(job.key).to eq('value')
        end
      end
    end
  end
end
