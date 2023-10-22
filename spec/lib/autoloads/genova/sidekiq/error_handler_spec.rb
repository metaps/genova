require 'rails_helper'

module Genova
  module Sidekiq
    describe ErrorHandler do
      let(:bot) { double(Genova::Slack::Interactive::Bot) }

      describe 'notify' do
        it 'should send slack message' do
          allow(bot).to receive(:error)
          allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)

          context_hash = {
            job: {
              jid: 'jid',
              args: ['arg']
            }
          }

          expect { Genova::Sidekiq::ErrorHandler.notify(RuntimeError.new, context_hash) }.to_not raise_error
        end
      end
    end
  end
end
