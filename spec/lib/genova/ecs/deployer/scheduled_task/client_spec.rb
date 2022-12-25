require 'rails_helper'

module Genova
  module Ecs
    module Deployer
      describe Client do
        let(:client) { Ecs::Deployer::ScheduledTask::Client.new('cluster') }
        let(:eventbridge) { double(Aws::EventBridge::Client) }

        before do
          allow(Aws::EventBridge::Client).to receive(:new).and_return(eventbridge)
        end

        describe 'exist_rule?' do
          context 'when rule exist' do
            it 'shuold be return true' do
              allow(eventbridge).to receive(:list_rules).and_return(rules: ['rule'])
              expect(client.exist_rule?('rule')).to eq(true)
            end
          end

          context 'when rule does not exist' do
            it 'shuold be return false' do
              allow(eventbridge).to receive(:list_rules).and_return(rules: [])
              expect(client.exist_rule?('rule')).to eq(false)
            end
          end
        end
      end
    end
  end
end
