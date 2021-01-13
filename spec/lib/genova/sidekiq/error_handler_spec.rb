require 'rails_helper'

module Genova
  module Sidekiq
    describe ErrorHandler do
      let(:bot_mock) { double(Genova::Slack::Bot) }

      describe 'notify' do
        it 'should be send slack message' do
          allow(bot_mock).to receive(:post_error)
          allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)

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
