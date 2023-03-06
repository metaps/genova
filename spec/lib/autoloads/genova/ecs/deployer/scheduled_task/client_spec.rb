require 'rails_helper'

module Genova
  module Ecs
    module Deployer
      describe Client do
        let(:deploy_job) do
          DeployJob.create!(
            id: DeployJob.generate_id,
            mode: DeployJob.mode.find_value(:manual),
            type: DeployJob.type.find_value(:service),
            account: Settings.github.account,
            repository: 'repository',
            cluster: 'cluster'
          )
        end
        let(:client) { Ecs::Deployer::ScheduledTask::Client.new(deploy_job) }
        let(:eventbridge) { double(Aws::EventBridge::Client) }

        before do
          DeployJob.collection.drop
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

        describe 'exist_target?' do
          let(:target) { double(Aws::EventBridge::Types::Target) }
          let(:list_targets_rule_response) { double(Aws::EventBridge::Types::ListTargetsByRuleResponse) }

          context 'when target exist' do
            it 'shuold be return true' do
              allow(target).to receive(:id).and_return('target')
              allow(list_targets_rule_response).to receive(:targets).and_return([target])
              allow(eventbridge).to receive(:list_targets_by_rule).and_return(list_targets_rule_response)
              expect(client.exist_target?('rule', 'target')).to eq(true)
            end
          end

          context 'when target does not exist' do
            it 'shuold be return false' do
              allow(target).to receive(:id).and_return('not_target')
              allow(list_targets_rule_response).to receive(:targets).and_return([target])
              allow(eventbridge).to receive(:list_targets_by_rule).and_return(list_targets_rule_response)
              expect(client.exist_target?('rule', 'target')).to eq(false)
            end
          end
        end

        describe 'update' do
          let(:target) do
            {
              ecs_parameters: { task_definition_arn: 'task_definition_arn' }
            }
          end

          it 'should be update deploy_job status' do
            allow(client).to receive(:exist_rule?).and_return(true)
            allow(client).to receive(:exist_target?).and_return(true)
            allow(eventbridge).to receive(:put_rule)
            allow(eventbridge).to receive(:put_targets)

            expect { client.update('name', 'schedule_expression', target) }.to_not raise_error
            expect(deploy_job.status).to eq(DeployJob.status.find_value(:success))
          end
        end
      end
    end
  end
end
