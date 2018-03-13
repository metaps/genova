require 'rails_helper'

module Genova
  module Slack
    describe Greeting do
      describe 'hello' do
        let(:slack_web_client_mock) { double('::Slack::Web::Client') }

        it 'should be call bot' do
          allow(::Slack::Web::Client).to receive(:new).and_return(slack_web_client_mock)
          allow(slack_web_client_mock).to receive(:chat_postMessage)

          Genova::Slack::Greeting.hello
          expect(slack_web_client_mock).to have_received(:chat_postMessage).once
        end
      end
    end
  end
end
